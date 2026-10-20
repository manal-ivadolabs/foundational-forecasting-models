#!/usr/bin/env bash
# Fails when any tracked symlink no longer resolves, whether or not the link itself is in the commit.
set -euo pipefail

status=0
while IFS= read -r link; do
  if [ ! -e "$link" ]; then
    echo "$link -> $(readlink "$link"): broken symlink" >&2
    status=1
  fi
done < <(git ls-files -s | awk '$1 == "120000" { print $4 }')
exit $status
