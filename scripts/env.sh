#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/env.sh select   — interactive environment selector + create
#   ./scripts/env.sh current  — show active environment
#   ./scripts/env.sh init     — non-interactive bootstrap (used by make setup)

PROJECT_NAME="project_name_to_change"
PROJECT_NAME_UPPER=$(echo "$PROJECT_NAME" | tr '[:lower:]' '[:upper:]')

create_env() {
  local target="$1"
  printf "PYTHONPATH=%s\nKICKSTART_NAME_OVERWRITE=%s\n%s_ROOT=%s\n" "${PWD}" "${PROJECT_NAME_UPPER}" "${PROJECT_NAME_UPPER}" "${PWD}" > "$target"
}

# Silent setup: creates .env.local (if absent) and symlinks .env to it.
cmd_init() {
  if [ ! -f .env.local ]; then
    create_env .env.local
  fi
  rm -f .env && ln -s .env.local .env
  echo "✓ Environment ready (.env → .env.local)"
}

# Interactive menu: switch between .env.* files or create a new one.
cmd_select() {
  envfiles=()
  while IFS= read -r f; do
    envfiles+=("$f")
  done < <(ls -1 .env.* 2>/dev/null | grep -v '\.env\.example$' | grep -v '\.bak$' | sort)

  local labels=()
  local current_link=""
  [ -L .env ] && current_link="$(readlink .env)"

  for f in "${envfiles[@]+"${envfiles[@]}"}"; do
    local label="${f#.env.}"
    if [ "$current_link" = "$f" ]; then
      labels+=("$label  ← active")
    else
      labels+=("$label")
    fi
  done
  labels+=("Create new environment")

  echo ""
  echo "Available environments:"
  echo "─────────────────────────"

  COLUMNS=1
  select choice in "${labels[@]}"; do
    if [ "$choice" = "Create new environment" ]; then
      printf "Enter environment name: "
      read -r name

      if [ -z "$name" ]; then
        echo "No name provided."
        exit 1
      fi
      if ! [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Invalid name. Use only letters, numbers, hyphens, and underscores."
        exit 1
      fi

      local target=".env.${name}"
      if [ -f "$target" ]; then
        echo "Error: $target already exists."
        exit 1
      fi

      create_env "$target"
      echo "Created $target"
      rm -f .env && ln -s "$target" .env
      echo "✓ Switched to $name (.env → $target)"
    elif [ -n "$choice" ]; then
      local idx=$((REPLY - 1))
      local selected="${envfiles[$idx]}"
      rm -f .env && ln -s "$selected" .env
      echo "✓ Switched to ${selected#.env.} (.env → $selected)"
    else
      echo "Invalid selection."
      continue
    fi
    break
  done
}

# Prints the name of the active environment.
cmd_current() {
  if [ -L .env ]; then
    readlink .env | sed 's/^\.env\.//'
  elif [ -f .env ]; then
    echo ".env exists but is not a symlink (run 'make env' to switch)"
  else
    echo "No .env file found (run 'make env' to create one)"
  fi
}

# --- Entry point ---
case "${1:-select}" in
  init)    cmd_init    ;;
  select)  cmd_select  ;;
  current) cmd_current ;;
  *)
    echo "Usage: $0 {init|select|current}"
    exit 1
    ;;
esac
