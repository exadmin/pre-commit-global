#!/bin/sh

# Registers 'hooks-global' as global-hooks folder irrelevantly to the place where the script was called from

CYAN='\033[0;36m'
NC='\033[0m' # No Color (reset)
PREFIX="${CYAN}[QUBERSHIP]${NC}"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
HOOKS_DIR="$SCRIPT_DIR/hooks-global"

if [ -e "$HOOKS_DIR" ]; then
  git config --global core.hooksPath "$HOOKS_DIR"
  echo -e "${PREFIX} [OK] Global hooks are set to $HOOKS_DIR"
else
  echo -e "${PREFIX} [ERROR] hooks-global folder not found at: \"$HOOKS_DIR\""
fi
