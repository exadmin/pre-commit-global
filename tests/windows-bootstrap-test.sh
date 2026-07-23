#!/bin/sh

set -u

PATH="/usr/bin:/bin:$PATH"
export PATH

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/hooks-bootstrap-test.XXXXXX")"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  if [ -f "$TEST_ROOT/hook-output.log" ]; then
    printf '%s\n' '--- hook output ---' >&2
    cat "$TEST_ROOT/hook-output.log" >&2
  fi
  exit 1
}

HOOKS_PATH="$TEST_ROOT/hooks-global"
MINIMAL_BIN="$TEST_ROOT/minimal-bin"
mkdir -p "$HOOKS_PATH" "$MINIMAL_BIN"
cp "$PROJECT_ROOT/hooks-global/pre-commit" "$HOOKS_PATH/pre-commit"
cp "$PROJECT_ROOT/hooks-global/pre-commit-addon" "$HOOKS_PATH/pre-commit-addon"
if [ -f "$PROJECT_ROOT/hooks-global/_bootstrap" ]; then
  cp "$PROJECT_ROOT/hooks-global/_bootstrap" "$HOOKS_PATH/_bootstrap"
fi
printf '%s\n' "$(date +%s)" > "$HOOKS_PATH/.last_pull_timestamp"

cat > "$MINIMAL_BIN/git" <<'EOF'
#!/bin/sh
case "$*" in
  "--exec-path")
    printf '%s\n' "$TEST_GIT_EXEC_PATH"
    ;;
  "config --global core.hooksPath")
    printf '%s\n' "$TEST_HOOKS_PATH"
    ;;
  *)
    exit 0
    ;;
esac
EOF
chmod +x "$MINIMAL_BIN/git" "$HOOKS_PATH/pre-commit" "$HOOKS_PATH/pre-commit-addon"

TEST_GIT_EXEC_PATH="$(git --exec-path)"
TEST_HOOKS_PATH="$HOOKS_PATH"
export TEST_GIT_EXEC_PATH TEST_HOOKS_PATH

PATH="$MINIMAL_BIN" /bin/sh "$HOOKS_PATH/pre-commit" > "$TEST_ROOT/hook-output.log" 2>&1
HOOK_EXIT=$?

[ "$HOOK_EXIT" -eq 0 ] || fail "pre-commit exited with $HOOK_EXIT under a restricted PATH"

EXPECTED_HOOKS='
applypatch-msg
commit-msg
commit-msg-addon
fsmonitor-watchman
post-update
pre-applypatch
pre-commit
pre-commit-addon
pre-merge-commit
pre-push
pre-rebase
pre-receive
prepare-commit-msg
push-to-checkout
sendemail-validate
update'

for HOOK_NAME in $EXPECTED_HOOKS; do
  grep -F '. "$GLOBAL_HOOKS_PATH/_bootstrap"' "$PROJECT_ROOT/hooks-global/$HOOK_NAME" >/dev/null 2>&1 ||
    fail "$HOOK_NAME does not load the shared bootstrap"
done

printf '%s\n' 'PASS: windows bootstrap'
