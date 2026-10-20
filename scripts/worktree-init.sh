#!/usr/bin/env bash
# Usage: scripts/worktree-init.sh
# Copies the main worktree's env files, re-pointed at this one, and syncs the venv.
set -euo pipefail

# Git exports these into hooks, and they would point every git call below at the wrong tree.
unset GIT_DIR GIT_WORK_TREE
cd "$(git rev-parse --show-toplevel)"

# `git worktree list` names the main worktree directly, so this also holds for a
# bare repo or a --separate-git-dir setup where the git dir isn't inside it.
main_worktree=$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')
[ "$main_worktree" = "$PWD" ] && exit 0

if [ ! -e .env ] && [ ! -L .env ]; then
  shopt -s nullglob
  (
    umask 077 # The env files hold secrets: make every copy owner-only.
    for f in "$main_worktree"/.env "$main_worktree"/.env.*; do
      [ -e "$f" ] || [ -L "$f" ] || continue
      name="${f##*/}"
      [ "$name" = .env.example ] && continue
      if [ -L "$f" ]; then
        cp -P "$f" "$name"
      else
        content=$(cat "$f"; printf x) # $() strips trailing newlines; the sentinel guards them
        content=${content%x}
        printf '%s' "${content//"$main_worktree"/"$PWD"}" > "$name"
      fi
    done
    [ -e .env ] || bash scripts/env.sh init
  )
fi
make install-deps
