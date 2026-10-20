#!/usr/bin/env bash
#
# scripts/mirror.sh — Bootstrap zero-secret (WIF) Git mirroring through a GCS bucket.
#
# What it does:
#   1. Source repo (this repo): installs .github/workflows/mirror-push.yml. On every push to
#      main it bundles the repo (--all) plus LFS objects and uploads them to a GCS bucket.
#   2. Target repo: on an orphan branch "il-mirror-sync-runner" it installs .github/workflows/mirror-pull.yml.
#      On a schedule the puller downloads the bundle, restores LFS, RENAMES .github/workflows ->
#      .github/disabled-workflows (so the mirror keeps the workflow files but never runs them),
#      and force-pushes every branch (plus tags) onto the target — overwriting target branches of
#      the same name, but leaving the orphan "il-mirror-sync-runner" branch (and any target-only branch) intact.
#
# Auth is Workload Identity Federation — no long-lived secrets. The GCS bucket + WIF provider
# are provisioned out-of-band (see the il-mirror PR process) and injected below.
#
set -euo pipefail

# --------------------------------------------------------------------------------------
# Compliance gate — mirroring client code into our systems requires prior client approval.
# Defaults to "no" so an empty/accidental answer aborts before anything is touched.
# --------------------------------------------------------------------------------------
read -r -p "Has the client approved the mirroring of the code into our systems? [y/N] " approval || true
case "$approval" in
  [yY] | [yY][eE][sS]) ;;
  *) echo "Client approval not confirmed — aborting."; exit 1 ;;
esac

# The directory mirror.sh is run from is the SOURCE repo's working tree (Phase 1 writes
# .github/workflows/ here). We cd into temp clones below and must return to it.
START_DIR="$(pwd)"

# Temp dirs created during the run are removed on exit. Each phase appends its dir here so
# a single EXIT trap covers all of them — a per-phase `trap ... EXIT` would clobber earlier
# ones and leak their dirs.
_TMPDIRS=()
_cleanup() {
  local d
  for d in "${_TMPDIRS[@]:-}"; do
    [ -n "${d:-}" ] && rm -rf "$d"
  done
}
trap _cleanup EXIT

# --------------------------------------------------------------------------------------
# Configuration — set per downstream project.
# --------------------------------------------------------------------------------------
# Take the target URL from IL_MIRROR_TARGET_REPO_URL when set (non-interactive/CI);
# otherwise prompt for it. The IL_MIRROR_ prefix avoids collisions with other tooling.
TARGET_REPO_URL="${IL_MIRROR_TARGET_REPO_URL:-}"
if [ -z "$TARGET_REPO_URL" ]; then
  read -r -p "Please enter the GitHub clone URL of the target repo to mirror into: " TARGET_REPO_URL || true
fi
if [ -z "${TARGET_REPO_URL:-}" ]; then
  echo "No target repository URL provided — aborting." >&2
  exit 1
fi

# Derive an "org/repo" slug from a GitHub URL (supports git@ and https:// forms).
slug_from_url() {
  printf '%s' "$1" | sed -E 's#(git@github\.com:|https://github\.com/)##; s#\.git$##'
}

TARGET_REPO_SLUG="$(slug_from_url "$TARGET_REPO_URL")"

# The SOURCE is implicitly the current local git checkout (the pusher bundles `git --all`
# from this working tree). Resolve its remote URL/slug — in the same format as the target —
# so the operator can see exactly what is being mirrored FROM.
SOURCE_REPO_URL="$(git remote get-url origin 2>/dev/null || true)"
if [ -n "$SOURCE_REPO_URL" ]; then
  SOURCE_REPO_SLUG="$(slug_from_url "$SOURCE_REPO_URL")"
else
  SOURCE_REPO_URL="(no 'origin' remote configured)"
  SOURCE_REPO_SLUG="$(basename "$(git rev-parse --show-toplevel)")"
fi

MIRROR_SCHEDULE="0 12,22 * * *"
MIRROR_SCHEDULE_HUMAN="at 12:00 and 22:00 Montreal time daily"
RUNNER_BRANCH="il-mirror-sync-runner"

# --------------------------------------------------------------------------------------
# Sanity check — show the operator the source (this repo) and the target in the same
# format, and require explicit confirmation before mutating either repository.
# --------------------------------------------------------------------------------------
echo "This will set up one-way Git mirroring:"
echo
echo "   SOURCE (this repo):  ${SOURCE_REPO_SLUG}"
echo "                        ${SOURCE_REPO_URL}"
echo "   TARGET (mirror):     ${TARGET_REPO_SLUG}"
echo "                        ${TARGET_REPO_URL}"
echo
echo "The SOURCE will be copied on every push to main and synced onto the TARGET ${MIRROR_SCHEDULE_HUMAN}."
read -r -p "Proceed? [y/N] " reply || true
case "$reply" in
  [yY] | [yY][eE][sS]) ;;
  *) echo "Aborted."; exit 1 ;;
esac

# --------------------------------------------------------------------------------------
# GCP infrastructure (provisioned via the il-mirror PR process).
# --------------------------------------------------------------------------------------
echo "Provisioning/Fetching GCP Infrastructure..."
# ======================================================================================
# Register the mirror with the il-mirror infra repo (which provisions the bucket + WIF).
#
# We open a PR adding ONE entry to il-mirror's infra/access/mirrors.auto.tfvars and then
# carry on — we do NOT wait for that PR. Its only job is to make the GCS bucket + WIF
# provider actually exist in GCP. Both names are fully deterministic from il-mirror's
# naming convention (see its README "Add a mirror"), so we reconstruct GCP_BUCKET and
# WIF_PROVIDER right here. That is exactly the info the PR's CI would otherwise echo back,
# which is why this step is non-blocking: nothing below depends on the PR's output.
# (Caveat: the bucket + WIF don't physically exist until the PR merges and il-mirror's CI
# applies, so the mirror workflows can't authenticate until then — but bootstrapping the
# two repositories does not block on it.)
# ======================================================================================
IL_MIRROR_INFRA_REPO="${IL_MIRROR_INFRA_REPO:-ivado-labs/il-mirror}"
IL_MIRROR_TFVARS="infra/access/mirrors.auto.tfvars"
IL_MIRROR_PROJECT_ID="il-mirror"          # bucket prefix: <project_id>-<source_org>-<source_repo>
IL_MIRROR_PROJECT_NUMBER="935498631455"   # GCP project number embedded in the WIF provider name

# gh (clone + PR) is used to register the mirror automatically, but it is NOT required:
# every value below is derived locally. When gh is missing or unauthenticated we skip the
# auto-PR and instead point the operator at il-mirror's PR list (see the GH_OK=0 branch).
GH_OK=1
if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
  GH_OK=0
fi

# Split the "org/repo" slugs. The source MUST have an org — it becomes part of both the
# bucket name and the mirror key — so a repo with no 'origin' remote can't be mirrored.
case "$SOURCE_REPO_SLUG" in
  */*) SOURCE_ORG="${SOURCE_REPO_SLUG%%/*}"; SOURCE_REPO="${SOURCE_REPO_SLUG##*/}" ;;
  *)
    echo "ERROR: cannot determine source org/repo from '${SOURCE_REPO_SLUG}'." >&2
    echo "       This repo needs an 'origin' remote like git@github.com:<org>/<repo>.git." >&2
    exit 1
    ;;
esac
case "$TARGET_REPO_SLUG" in
  */*) TARGET_ORG="${TARGET_REPO_SLUG%%/*}"; TARGET_REPO="${TARGET_REPO_SLUG##*/}" ;;
  *)
    echo "ERROR: target '${TARGET_REPO_SLUG}' is not in 'org/repo' form." >&2
    exit 1
    ;;
esac

# Lowercased "<source_org>-<source_repo>" slug — the basis for the mirror key below.
SOURCE_SLUG="$(printf '%s-%s' "$SOURCE_ORG" "$SOURCE_REPO" | tr '[:upper:]' '[:lower:]')"

# Bucket name: "<project_id>-<source_org>-<source_repo>", sanitized to [a-z0-9_-] and
# lowercased, then truncated to GCS's 63-char limit. il-mirror's OpenTofu config does the same,
# so the name we use matches the bucket it provisions.
bucket_base="$(printf '%s-%s-%s' "$IL_MIRROR_PROJECT_ID" "$SOURCE_ORG" "$SOURCE_REPO" \
  | sed -E 's/[^a-zA-Z0-9_-]+/-/g' | tr '[:upper:]' '[:lower:]')"
GCP_BUCKET="gs://${bucket_base:0:63}"

# Mirror key (the github_mirrors map key) becomes the WIF pool/provider id, capped at 32
# chars. Start from the source slug and auto-truncate (with a warning) if it's too long.
MIRROR_KEY="$SOURCE_SLUG"
if [ "${#MIRROR_KEY}" -gt 32 ]; then
  orig_key="$MIRROR_KEY"
  # Cut to 32 chars, then drop any trailing hyphen(s) the cut may have left.
  MIRROR_KEY="$(printf '%s' "$MIRROR_KEY" | cut -c1-32 | sed 's/-*$//')"
  echo "   ⚠️  Mirror key '${orig_key}' (${#orig_key} chars) exceeds the 32-char limit —"
  echo "       truncating to '${MIRROR_KEY}' and using that."
fi
WIF_PROVIDER="projects/${IL_MIRROR_PROJECT_NUMBER}/locations/global/workloadIdentityPools/${MIRROR_KEY}/providers/${MIRROR_KEY}"

# --- Validate every derived value; refuse to touch il-mirror unless they're well-formed.
errors=0
# Key: 4..32 chars of [a-z0-9-] (il-mirror's WIF provider id constraint). Length over 32 is
# auto-truncated above, so a failure here means invalid characters (or a too-short slug).
if ! printf '%s' "$MIRROR_KEY" | grep -Eq '^[a-z0-9-]{4,32}$'; then
  echo "ERROR: mirror key '${MIRROR_KEY}' is invalid (need 4-32 chars of [a-z0-9-])." >&2
  echo "       It is derived from <source_org>-<source_repo>; remove characters outside [a-z0-9-]." >&2
  errors=1
fi
# Bucket: 3..63 chars of [a-z0-9-_]. The construction above already guarantees this (sanitize
# + truncate to 63), so this is a safety-net assertion that our replica still matches the tofu config.
bucket_name="${GCP_BUCKET#gs://}"
if ! printf '%s' "$bucket_name" | grep -Eq '^[a-z0-9_-]{3,63}$'; then
  echo "ERROR: constructed bucket name '${bucket_name}' is invalid (expected 3-63 chars of [a-z0-9-_])." >&2
  errors=1
fi
# WIF provider resource name shape.
if ! printf '%s' "$WIF_PROVIDER" | grep -Eq '^projects/[0-9]+/locations/global/workloadIdentityPools/[a-z0-9-]{4,32}/providers/[a-z0-9-]{4,32}$'; then
  echo "ERROR: WIF provider '${WIF_PROVIDER}' is malformed." >&2
  errors=1
fi
if [ "$errors" -ne 0 ]; then
  echo "Aborting before touching ${IL_MIRROR_INFRA_REPO}." >&2
  exit 1
fi

echo "   Mirror key:    ${MIRROR_KEY}"
echo "   Bucket:        ${GCP_BUCKET}"
echo "   WIF provider:  ${WIF_PROVIDER}"

# --- Open (or reuse) the PR that adds the entry provisioning the bucket + WIF. ----------
# This whole block needs gh (clone + PR). When gh is unavailable we fall through to the
# GH_OK=0 branch, which tells the operator to open the PR by hand. The body below is kept
# at column 0 (not indented under the `if`) so the ENTRY/BODY heredocs stay byte-for-byte.
if [ "$GH_OK" = 1 ]; then
IL_MIRROR_DIR="$(mktemp -d)"
_TMPDIRS+=("$IL_MIRROR_DIR")
echo "==> Cloning ${IL_MIRROR_INFRA_REPO} to register the mirror..."
if ! gh repo clone "$IL_MIRROR_INFRA_REPO" "$IL_MIRROR_DIR" >/dev/null 2>&1; then
  echo "ERROR: failed to clone ${IL_MIRROR_INFRA_REPO} — check repo access and 'gh auth status'." >&2
  exit 1
fi

tfvars_path="${IL_MIRROR_DIR}/${IL_MIRROR_TFVARS}"
if [ ! -f "$tfvars_path" ]; then
  echo "ERROR: ${IL_MIRROR_TFVARS} not found in ${IL_MIRROR_INFRA_REPO}." >&2
  exit 1
fi

if grep -Eq "^[[:space:]]*\"${MIRROR_KEY}\"[[:space:]]*=" "$tfvars_path"; then
  # Already on main → bucket + WIF are (being) provisioned. Nothing to PR; just continue.
  echo "   Mirror '${MIRROR_KEY}' already present in ${IL_MIRROR_INFRA_REPO} — no PR needed."
else
  PR_BRANCH="add-mirror-${MIRROR_KEY}"
  cd "$IL_MIRROR_DIR"
  git config user.email >/dev/null 2>&1 || git config user.email "il-mirror-bot@users.noreply.github.com"
  git config user.name >/dev/null 2>&1 || git config user.name "il-mirror-bot"

  # Reuse an open PR for this mirror if one already exists (idempotent re-runs).
  existing_pr="$(gh pr list --head "$PR_BRANCH" --state open --json url --jq '.[0].url' 2>/dev/null || true)"
  if [ -n "$existing_pr" ]; then
    echo
    echo "🔗 A mirror-registration PR for '${MIRROR_KEY}' is already open and this script won't modify it:"
    echo "   ${existing_pr}"
    echo "   ⚠️  To push changes, close that PR and delete its branch '${PR_BRANCH}', then re-run."
    echo
    PR_FINAL_URL="$existing_pr"
    PR_FINAL_STATUS="already exists"
  else
    git checkout -b "$PR_BRANCH" >/dev/null 2>&1

    # Build the github_mirrors entry (SOURCE gets WRITE — it uploads the bundle; TARGET gets
    # READ — it downloads it) and insert it. No trailing inline comments: `tofu fmt` aligns
    # adjacent end-of-line comments to a name-length-dependent column, which breaks `fmt -check`.
    # The opening line may be the inline "github_mirrors = {}" or block "github_mirrors = {"
    # form; one awk pass handles both. Splitting {}→block here (not via sed) dodges the GNU/BSD
    # sed "\n" trap, and [ \t] (not [[:space:]]) keeps the regex mawk-portable.
    entry="$(cat <<ENTRY
  "${MIRROR_KEY}" = {
    source = { org = "${SOURCE_ORG}", repo = "${SOURCE_REPO}" }
    target = { org = "${TARGET_ORG}", repo = "${TARGET_REPO}" }
  }
ENTRY
)"
    awk -v entry="$entry" '
      !inserted && /^[ \t]*github_mirrors[ \t]*=[ \t]*\{\}[ \t]*$/ {
        sub(/\{\}[ \t]*$/, "{"); print; print entry; print "}"; inserted=1; next
      }
      !inserted && /^[ \t]*github_mirrors[ \t]*=[ \t]*\{[ \t]*$/ {
        print; print entry; inserted=1; next
      }
      { print }
      END { if (!inserted) exit 3 }
    ' "$IL_MIRROR_TFVARS" > "${IL_MIRROR_TFVARS}.new" || {
      echo "ERROR: could not find 'github_mirrors = {' in ${IL_MIRROR_TFVARS}." >&2
      exit 1
    }
    mv "${IL_MIRROR_TFVARS}.new" "$IL_MIRROR_TFVARS"

    # Best-effort: normalize the file so it matches il-mirror's `tofu fmt -check` CI exactly.
    # We use OpenTofu (tofu), falling back to terraform — fmt output is identical between them.
    # Skipped silently when neither is on PATH; the entry above is already fmt-clean by hand.
    if command -v tofu >/dev/null 2>&1; then
      tofu fmt "$IL_MIRROR_TFVARS" >/dev/null 2>&1 || true
    elif command -v terraform >/dev/null 2>&1; then
      terraform fmt "$IL_MIRROR_TFVARS" >/dev/null 2>&1 || true
    fi

    # Stage ONLY the tfvars file so the PR touches nothing else.
    git add "$IL_MIRROR_TFVARS"
    git commit -m "feat: add mirror ${MIRROR_KEY} (automated by 'make mirror')" >/dev/null
    if ! git push -u origin "$PR_BRANCH" >/dev/null 2>&1; then
      echo "ERROR: failed to push branch '${PR_BRANCH}' to ${IL_MIRROR_INFRA_REPO}." >&2
      exit 1
    fi

    PR_URL="$(gh pr create \
      --base main \
      --head "$PR_BRANCH" \
      --title "Add mirror: ${MIRROR_KEY} (automated by 'make mirror')" \
      --body "$(cat <<BODY
🤖 Opened automatically by the \`make mirror\` command.

Adds one \`github_mirrors\` entry to \`${IL_MIRROR_TFVARS}\` provisioning:

| | |
|---|---|
| **Mirror key** | \`${MIRROR_KEY}\` |
| **Bucket** | \`${GCP_BUCKET}\` |
| **WIF provider** | \`${WIF_PROVIDER}\` |
| **Source (WRITE)** | \`${SOURCE_ORG}/${SOURCE_REPO}\` |
| **Target (READ)** | \`${TARGET_ORG}/${TARGET_REPO}\` |

This PR edits **only** \`${IL_MIRROR_TFVARS}\`.
BODY
)")"
    echo "Mirror-registration PR opened (does NOT block this script): ${PR_URL}"
    echo "Once it merges, il-mirror's CI creates the bucket + WIF above."
    PR_FINAL_URL="$PR_URL"
    PR_FINAL_STATUS="created"
  fi
  cd "$START_DIR"
fi
else
  # gh unavailable — we can't open the PR here. Point the operator at il-mirror's PR list so
  # they can register the mirror by hand using the values already printed above.
  echo
  echo "⚠️ 'gh' unavailable — the mirror was NOT registered automatically."
  echo "   Open a PR as https://github.com/ivado-labs/il-mirror#add-a-mirror adding a"
  echo "   \"${MIRROR_KEY}\" entry to ${IL_MIRROR_TFVARS} for source"
  echo "   ${SOURCE_ORG}/${SOURCE_REPO} -> target ${TARGET_ORG}/${TARGET_REPO}."
  echo
fi
# ======================================================================================

# Portable in-place sed. GNU sed accepts a bare `-i`; BSD/macOS sed reads the next argument
# as a mandatory backup suffix, so `sed -i 's|...|' file` is misparsed there. Editing through
# a sibling temp file (same dir → atomic rename, same filesystem) behaves identically on both.
# Usage: sed_inplace <sed-args...> <file>.
sed_inplace() {
  local file="${@: -1}"
  local tmp
  tmp="$(mktemp "${file}.tmp.XXXXXX")"
  if sed "${@:1:$#-1}" "$file" > "$tmp"; then
    mv "$tmp" "$file"
  else
    rm -f "$tmp"
    return 1
  fi
}

# Replace the @@TOKENS@@ with the dynamic values in a workflow template.
inject() {
  local file="$1"
  sed_inplace \
    -e "s|@@WIF_PROVIDER@@|${WIF_PROVIDER}|g" \
    -e "s|@@GCP_BUCKET@@|${GCP_BUCKET}|g" \
    -e "s|@@TARGET_SLUG@@|${TARGET_REPO_SLUG}|g" \
    "$file"
}

# ======================================================================================
# Phase 1 — Source repository (this repo): the pusher workflow.
# ======================================================================================
echo "==> Configuring source repository (pusher)..."
mkdir -p .github/workflows

cp "$START_DIR/scripts/mirror-push.tmpl.yml" .github/workflows/mirror-push.yml

inject .github/workflows/mirror-push.yml

git add .github/workflows/mirror-push.yml

# ======================================================================================
# Phase 2 — Target repository: the puller workflow on an isolated orphan branch.
# ======================================================================================
echo "==> Configuring target repository (puller) at ${TARGET_REPO_SLUG}..."
TEMP_DIR="$(mktemp -d)"
_TMPDIRS+=("$TEMP_DIR")

git clone "$TARGET_REPO_URL" "$TEMP_DIR"
cd "$TEMP_DIR"
git config user.email >/dev/null 2>&1 || git config user.email "il-mirror-bot@users.noreply.github.com"
git config user.name >/dev/null 2>&1 || git config user.name "il-mirror-bot"

# Orphan branch so the runner survives the force-push that overwrites main.
# On a re-run the runner branch already exists on the remote (and may even be the
# clone's default branch, which would make `git checkout --orphan` fail). So reuse
# it when present — switch to it locally — and only create the orphan when it's absent.
if git ls-remote --exit-code --heads origin "$RUNNER_BRANCH" >/dev/null 2>&1; then
  echo "   Runner branch '${RUNNER_BRANCH}' already exists on the remote — reusing it."
  git checkout "$RUNNER_BRANCH"
else
  git checkout --orphan "$RUNNER_BRANCH"
  git rm -rf . >/dev/null 2>&1 || true
fi

mkdir -p .github/workflows
cp "$START_DIR/scripts/mirror-pull.tmpl.yml" .github/workflows/mirror-pull.yml

# @@SCHEDULE@@ is injected separately (it is not a path/URL). Same portable in-place
# approach as inject() — avoid `sed -i`, which differs between GNU and BSD/macOS sed.
sed_inplace "s|@@SCHEDULE@@|${MIRROR_SCHEDULE}|g" .github/workflows/mirror-pull.yml
sed_inplace "s|@@SCHEDULE_HUMAN@@|${MIRROR_SCHEDULE_HUMAN}|g" .github/workflows/mirror-pull.yml
inject .github/workflows/mirror-pull.yml

git add .github/workflows/mirror-pull.yml
# When reusing an existing runner branch the regenerated workflow may be identical,
# leaving nothing staged. We freshly cloned, so HEAD already matches the remote in
# that case — skip the commit (so `set -e` doesn't abort) and the push (a no-op).
if git diff --cached --quiet; then
  echo "   Runner workflow already up to date — nothing to commit or push."
else
  git commit -m "ci: add mirror sync runner"
  git push origin "$RUNNER_BRANCH"
fi

# Scheduled workflows only run from a repo's DEFAULT branch, so the runner branch must be
# the default. Try to set it automatically; warn (don't fail) if gh is unavailable (reusing
# the same GH_OK gate as the registration step above — covers missing AND unauthenticated).
if [ "$GH_OK" = 1 ]; then
  if gh repo edit "$TARGET_REPO_SLUG" --default-branch "$RUNNER_BRANCH"; then
    echo "Default branch of ${TARGET_REPO_SLUG} set to '${RUNNER_BRANCH}'."
  else
    echo "Could not set default branch using 'gh'."
    MANUAL_RUNNER_BRANCH_NEEDED=1
  fi
else
  echo "'gh' unavailable — Could not set default branch."
  MANUAL_RUNNER_BRANCH_NEEDED=1
fi

cd - >/dev/null
# temp dir removed by the EXIT trap.

# ======================================================================================
# Done.
# ======================================================================================
echo
if [ -n "${PR_FINAL_URL:-}" ]; then
  echo "🔗 PR ${PR_FINAL_STATUS}: ${PR_FINAL_URL}"
fi
echo "✅ Target repository bootstrapped on branch '${RUNNER_BRANCH}'."
if [ "${MANUAL_RUNNER_BRANCH_NEEDED:-0}" = 1 ]; then
  echo "➡️  Set Default branch to '${RUNNER_BRANCH}' on https://github.com/${TARGET_REPO_SLUG}/settings to enable scheduled workflows."
fi
echo "✅ Source repository configured. Commit & push your current branch to trigger the first mirror run!"
echo '➡️  git commit -m "chore: enable repository mirroring" .github/workflows/mirror-push.yml'
