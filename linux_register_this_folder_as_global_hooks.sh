#!/bin/sh

# Registers 'hooks-global' as global-hooks folder irrelevantly to the place where the script was called from

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
HOOKS_DIR="$SCRIPT_DIR/hooks-global"

if [ -e "$HOOKS_DIR" ]; then
  git config --global core.hooksPath "$HOOKS_DIR"
  echo "[OK] Global hooks are set to $HOOKS_DIR"
else
  echo "[ERROR] hooks-global folder not found at: \"$HOOKS_DIR\""
fi
