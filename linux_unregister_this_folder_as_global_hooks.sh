#!/bin/sh

# Unsets global git properties set by linux_register_this_folder_as_global_hooks.sh

CURRENT=$(git config --global --get core.hooksPath)

if [ -n "$CURRENT" ]; then
  git config --global --unset core.hooksPath
  echo "[OK] Global hooks are unset (was $CURRENT)"
else
  echo "[INFO] core.hooksPath is not set"
fi
