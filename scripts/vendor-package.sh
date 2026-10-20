#!/usr/bin/env bash
set -euo pipefail

# Downloads a package from the GCP Artifact Registry and vendors it locally.
# Usage: ./scripts/vendor-package.sh <package-name>
#
# The script will:
# 1. Resolve the installed version from the uv lockfile
# 2. Verify gcloud credentials
# 3. Download the source tarball from Artifact Registry
# 4. Extract it into the vendor/ directory
# 5. Update pyproject.toml to point to the vendored source

GCP_PROJECT="il-registry"
GCP_REPOSITORY="il-py-index"
GCP_LOCATION="northamerica-northeast1"
VENDOR_DIR="vendor"

# --- Validate input ---
if [ -z "${1:-}" ]; then
    echo "[ERROR] Package name is required."
    echo "Usage: $0 <package-name>"
    exit 1
fi

PKG="$1"
PKG_NORMALIZED="${PKG//-/_}"

# --- Resolve version from lockfile ---
echo "[INFO] Resolving ${PKG} version from lockfile..."
EXPORT_TMPFILE=$(mktemp)
EXPORT_ERRFILE=$(mktemp)
set +e
uv export --no-hashes > "$EXPORT_TMPFILE" 2> "$EXPORT_ERRFILE"
UV_EXIT=$?
set -e

if [ "$UV_EXIT" -ne 0 ]; then
    echo "[ERROR] 'uv export' failed (exit code: ${UV_EXIT}):"
    echo "  --- stdout ---"
    sed 's/^/  /' "$EXPORT_TMPFILE"
    echo "  --- stderr ---"
    sed 's/^/  /' "$EXPORT_ERRFILE"
    rm -f "$EXPORT_TMPFILE" "$EXPORT_ERRFILE"
    exit 1
fi

VERSION=$(grep "^${PKG}==" "$EXPORT_TMPFILE" | cut -d'=' -f3 || true)
if [ -z "$VERSION" ]; then
    # Package might already be vendored (path source), e.g. ./vendor/pkg_name-1.2.3
    VERSION=$(grep "^\./${VENDOR_DIR}/${PKG_NORMALIZED}-" "$EXPORT_TMPFILE" | sed "s|\./${VENDOR_DIR}/${PKG_NORMALIZED}-||" || true)
fi
rm -f "$EXPORT_TMPFILE" "$EXPORT_ERRFILE"
if [ -z "$VERSION" ]; then
    echo "[ERROR] ${PKG} not found in lockfile."
    echo ""
    echo "  Possible causes:"
    echo "    - The package is not in your dependencies"
    echo "    - The package was already vendored (source changed in pyproject.toml)"
    echo "    - The package name is misspelled"
    echo ""
    echo "  Hint: Run 'uv export --no-hashes | grep ${PKG}' to check."
    exit 1
fi

echo "[OK] Found ${PKG}==${VERSION} (normalized: ${PKG_NORMALIZED})"

# --- Check gcloud credentials ---
echo "[INFO] Checking gcloud credentials..."
if ! gcloud auth print-access-token >/dev/null 2>&1 && \
   ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
    echo "[ERROR] No valid gcloud credentials found."
    echo "  Run 'gcloud auth login' to authenticate."
    exit 1
fi
echo "[OK] Credentials valid"

# --- Clean previous vendor if exists ---
if [ -d "${VENDOR_DIR}/${PKG_NORMALIZED}-${VERSION}" ]; then
    echo "[INFO] Removing existing vendor/${PKG_NORMALIZED}-${VERSION}..."
    rm -rf "${VENDOR_DIR}/${PKG_NORMALIZED}-${VERSION}"
fi

# --- Download ---
echo "[INFO] Downloading ${PKG}/${PKG_NORMALIZED}-${VERSION}.tar.gz..."
mkdir -p "$VENDOR_DIR"

ARTIFACT_PATH="${PKG}/${PKG_NORMALIZED}-${VERSION}.tar.gz"
if ! gcloud artifacts files download \
    --project="$GCP_PROJECT" \
    --repository="$GCP_REPOSITORY" \
    --location="$GCP_LOCATION" \
    "$ARTIFACT_PATH" \
    --destination "$VENDOR_DIR" 2>&1; then
    echo ""
    echo "[ERROR] Failed to download artifact."
    echo "  Artifact path: ${ARTIFACT_PATH}"
    echo ""
    echo "  Possible causes:"
    echo "    - The artifact does not exist in the registry"
    echo "    - You don't have permission to access the registry"
    echo "    - The project/repository/location is incorrect"
    exit 1
fi

# --- Extract (gcloud URL-encodes the filename) ---
echo "[INFO] Extracting tarball..."
cd "$VENDOR_DIR"
ENCODED_FILE=$(ls | grep "${PKG_NORMALIZED}.*tar.gz" | head -1 || true)
if [ -z "$ENCODED_FILE" ]; then
    echo "[ERROR] Downloaded tarball not found in ${VENDOR_DIR}/."
    echo "  Expected a file matching: ${PKG_NORMALIZED}.*tar.gz"
    exit 1
fi
CLEAN_FILE="${PKG_NORMALIZED}-${VERSION}.tar.gz"
mv "$ENCODED_FILE" "$CLEAN_FILE"
tar -xzf "$CLEAN_FILE" && rm "$CLEAN_FILE"
cd ..

echo "[OK] Extracted to ${VENDOR_DIR}/${PKG_NORMALIZED}-${VERSION}"

# --- Update pyproject.toml ---
echo "[INFO] Updating pyproject.toml to use vendored source..."
if grep -q "${PKG} = { index = \"gcp-private\" }" pyproject.toml; then
    sed -i '' "s|${PKG} = { index = \"gcp-private\" }|${PKG} = { path = \"${VENDOR_DIR}/${PKG_NORMALIZED}-${VERSION}\", editable = false }|" pyproject.toml
    echo "[OK] pyproject.toml updated"
elif grep -q "${PKG} = { path = \"${VENDOR_DIR}/" pyproject.toml; then
    sed -i '' "s|${PKG} = { path = \"${VENDOR_DIR}/[^\"]*\", editable = false }|${PKG} = { path = \"${VENDOR_DIR}/${PKG_NORMALIZED}-${VERSION}\", editable = false }|" pyproject.toml
    echo "[OK] pyproject.toml updated (replaced existing vendored path)"
else
    echo "[WARN] Could not find ${PKG} source entry in pyproject.toml [tool.uv.sources]."
    echo "  You may need to manually add:"
    echo "  ${PKG} = { path = \"${VENDOR_DIR}/${PKG_NORMALIZED}-${VERSION}\", editable = false }"
fi

echo ""
echo "Done! Run 'uv sync' to install from vendor."
