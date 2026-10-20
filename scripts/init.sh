#!/usr/bin/env bash
set -euo pipefail

# --- Rename project ---

read -p "Enter new project name: " NEW_NAME

export LC_ALL=C
grep -rl "project_name_to_change" . --exclude-dir=.git --exclude-dir=.venv \
  | xargs sed -i '' "s/project_name_to_change/${NEW_NAME}/g"

if [ -d "project_name_to_change" ]; then
  mv "project_name_to_change" "${NEW_NAME}"
fi

# --- Select CI/CD provider ---

GITHUB_FILES=(".github/workflows" "CODEOWNERS" ".github/SETUP.md")
ADO_FILES=(".ado")
GITLAB_FILES=(".gitlab-ci.yml" ".gitlab")

echo ""
echo "Select your CI/CD provider:"
select CICD_CHOICE in "GitHub Actions" "Azure DevOps" "GitLab CI/CD"; do
  if [ "${CICD_CHOICE}" = "GitHub Actions" ]; then
    rm -rf "${ADO_FILES[@]}" "${GITLAB_FILES[@]}"
    ln -sf "../.github/SETUP.md" docs/cicd_setup.md
    REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
    OWNER_REPO=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/]([^/]+/[^/]+)(\.git)?$|\1|')
    if [ -n "$OWNER_REPO" ] && [ "$OWNER_REPO" != "$REMOTE_URL" ]; then
      sed -i '' "s|!\[Coverage\](coverage\.svg)|![Coverage](https://github.com/${OWNER_REPO}/raw/refs/heads/badges/coverage.svg)|" README.md
    else
      echo "Note: update the coverage badge URL in README.md to: https://github.com/OWNER/REPO/raw/refs/heads/badges/coverage.svg"
    fi
    echo "Next: see .github/SETUP.md for setup instructions."
  elif [ "${CICD_CHOICE}" = "Azure DevOps" ]; then
    rm -rf "${GITHUB_FILES[@]}" "${GITLAB_FILES[@]}"
    ln -sf "../.ado/SETUP.md" docs/cicd_setup.md
    echo "Next: see .ado/SETUP.md for setup instructions."
  elif [ "${CICD_CHOICE}" = "GitLab CI/CD" ]; then
    rm -rf "${GITHUB_FILES[@]}" "${ADO_FILES[@]}"
    ln -sf "../.gitlab/SETUP.md" docs/cicd_setup.md
    echo "Next: see .gitlab/SETUP.md for setup instructions."
  else
    echo "Invalid choice — no CI/CD files removed."
  fi
  break
done

# --- Done ---

echo "Done! Project initialized as ${NEW_NAME}"
