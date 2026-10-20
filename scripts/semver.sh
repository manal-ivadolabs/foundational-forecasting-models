#!/usr/bin/env bash
# Computes the next semver version from the latest git tag.
# Usage: scripts/semver.sh <major|minor|patch>
# Output: the new version string, e.g. "1.2.3"

set -euo pipefail

release_type="${1:?Usage: $0 <major|minor|patch>}"

prev_tag=$(git tag --sort=-version:refname | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | head -1 || echo "0.0.0")
prev_tag="${prev_tag#v}"
IFS='.' read -ra ver <<< "$prev_tag"

case "$release_type" in
  major) echo "$((ver[0]+1)).0.0" ;;
  minor) echo "${ver[0]}.$((ver[1]+1)).0" ;;
  patch) echo "${ver[0]}.${ver[1]}.$((ver[2]+1))" ;;
  *)     echo "Invalid release_type: '$release_type'" >&2; exit 1 ;;
esac
