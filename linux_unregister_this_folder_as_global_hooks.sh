#!/bin/sh

# Unsets global git properties set by linux_register_this_folder_as_global_hooks.sh

CYAN='\033[0;36m'
NC='\033[0m' # No Color (reset)
PREFIX="${CYAN}[QUBERSHIP]${NC}"

CURRENT=$(git config --global --get core.hooksPath)

if [ -n "$CURRENT" ]; then
  git config --global --unset core.hooksPath
  echo -e "${PREFIX} [OK] Global hooks are unset (was $CURRENT)"
else
  echo -e "${PREFIX} [INFO] core.hooksPath is not set"
fi
