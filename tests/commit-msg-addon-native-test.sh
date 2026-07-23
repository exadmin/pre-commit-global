#!/bin/sh

set -u

PATH="/usr/bin:/bin:$PATH"
export PATH

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cfcli-hook-test.XXXXXX")"
TEST_COUNT=0

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  if [ -f "${HOOK_OUTPUT:-}" ]; then
    printf '%s\n' '--- hook output ---' >&2
    cat "$HOOK_OUTPUT" >&2
  fi
  if [ -f "${TEST_CFCLI_LOG:-}" ]; then
    printf '%s\n' '--- CyberFerret arguments ---' >&2
    cat "$TEST_CFCLI_LOG" >&2
  fi
  exit 1
}

assert_file_exists() {
  [ -f "$1" ] || fail "Expected file to exist: $1"
}

assert_file_not_exists() {
  [ ! -e "$1" ] || fail "Expected path not to exist: $1"
}

assert_file_contains() {
  grep -F -- "$2" "$1" >/dev/null 2>&1 || fail "Expected '$2' in $1"
}

assert_equals() {
  [ "$1" = "$2" ] || fail "Expected '$2', got '$1'"
}

write_fake_commands() {
  mkdir -p "$FAKE_BIN"

  cat > "$FAKE_BIN/uname" <<'EOF'
#!/bin/sh
case "${1:-}" in
  -s) printf '%s\n' "$TEST_UNAME_S" ;;
  -m) printf '%s\n' "$TEST_UNAME_M" ;;
  *) printf '%s\n' "$TEST_UNAME_S" ;;
esac
EOF

  cat > "$FAKE_BIN/date" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "+%s" ]; then
  printf '%s\n' "$TEST_NOW"
else
  exec /usr/bin/date "$@"
fi
EOF

  cat > "$FAKE_BIN/curl" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$TEST_CURL_LOG"

OUTPUT_PATH=
PREVIOUS=
for ARGUMENT in "$@"; do
  if [ "$PREVIOUS" = "--output" ]; then
    OUTPUT_PATH="$ARGUMENT"
  fi
  PREVIOUS="$ARGUMENT"
done

case "$*" in
  *api.github.com*)
    if [ "${TEST_API_FAIL:-0}" = "1" ]; then
      exit 28
    fi
    printf '%s\n' "$TEST_API_RESPONSE"
    ;;
  *)
    if [ "${TEST_DOWNLOAD_FAIL:-0}" = "1" ]; then
      exit 22
    fi
    cp "$TEST_DOWNLOAD_SOURCE" "$OUTPUT_PATH"
    ;;
esac
EOF

  cat > "$FAKE_BIN/git" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "--exec-path" ]; then
  printf '%s\n' "/usr/lib/git-core"
else
  exec "$TEST_REAL_GIT" "$@"
fi
EOF

  chmod +x "$FAKE_BIN/uname" "$FAKE_BIN/date" "$FAKE_BIN/curl" "$FAKE_BIN/git"
}

write_native_executable() {
  TARGET_PATH="$1"
  MARKER="$2"
  cat > "$TARGET_PATH" <<EOF
#!/bin/sh
printf '%s\n' '$MARKER' "\$1" "\$2" "\$3" >> "\$TEST_CFCLI_LOG"
exit "\${TEST_CFCLI_EXIT:-0}"
EOF
  chmod +x "$TARGET_PATH"
}

setup_scenario() {
  TEST_COUNT=$((TEST_COUNT + 1))
  SCENARIO_ROOT="$TEST_ROOT/scenario-$TEST_COUNT"
  HOOKS_PATH="$SCENARIO_ROOT/install/hooks-global"
  DIST_PATH="$SCENARIO_ROOT/install/cyberferret-dist"
  REPO_PATH="$SCENARIO_ROOT/repository"
  FAKE_BIN="$SCENARIO_ROOT/fake-bin"
  TEST_CURL_LOG="$SCENARIO_ROOT/curl.log"
  TEST_CFCLI_LOG="$SCENARIO_ROOT/cfcli.log"
  TEST_DOWNLOAD_SOURCE="$SCENARIO_ROOT/downloaded-cfcli"
  HOOK_OUTPUT="$SCENARIO_ROOT/hook-output.log"
  MESSAGE_PATH="$REPO_PATH/commit-message.txt"
  GIT_CONFIG_GLOBAL="$SCENARIO_ROOT/gitconfig"

  mkdir -p "$HOOKS_PATH" "$DIST_PATH" "$REPO_PATH/.qubership"
  cp "$PROJECT_ROOT/hooks-global/commit-msg-addon" "$HOOKS_PATH/commit-msg-addon"
  cp "$PROJECT_ROOT/hooks-global/_bootstrap" "$HOOKS_PATH/_bootstrap"
  chmod +x "$HOOKS_PATH/commit-msg-addon"
  printf '{}\n' > "$REPO_PATH/.qubership/grand-report.json"
  printf 'commit message\n' > "$MESSAGE_PATH"
  write_native_executable "$TEST_DOWNLOAD_SOURCE" "downloaded"
  write_fake_commands

  git -C "$REPO_PATH" init -q
  git -C "$REPO_PATH" config user.email test@example.com
  git -C "$REPO_PATH" config user.name Test
  git -C "$REPO_PATH" config core.autocrlf false
  printf 'changed\n' > "$REPO_PATH/changed.txt"
  git -C "$REPO_PATH" add changed.txt .qubership/grand-report.json
  git config --file "$GIT_CONFIG_GLOBAL" core.hooksPath "$HOOKS_PATH"
  EXPECTED_REPO_PATH="$(git -C "$REPO_PATH" rev-parse --show-toplevel)"

  TEST_UNAME_S=Linux
  TEST_UNAME_M=x86_64
  TEST_NOW=200000
  TEST_API_RESPONSE='{"tag_name":"v2.0.0"}'
  TEST_API_FAIL=0
  TEST_DOWNLOAD_FAIL=0
  TEST_CFCLI_EXIT=0
  TEST_REAL_GIT="$(command -v git)"

  export GIT_CONFIG_GLOBAL TEST_UNAME_S TEST_UNAME_M TEST_NOW TEST_API_RESPONSE
  export TEST_API_FAIL TEST_DOWNLOAD_FAIL TEST_CFCLI_EXIT
  export TEST_CURL_LOG TEST_CFCLI_LOG TEST_DOWNLOAD_SOURCE TEST_REAL_GIT
}

run_hook() {
  (
    cd "$REPO_PATH" || exit 99
    PATH="$FAKE_BIN:$PATH" "$HOOKS_PATH/commit-msg-addon" "$MESSAGE_PATH"
  ) >"$HOOK_OUTPUT" 2>&1
  HOOK_EXIT=$?
}

install_existing_executable() {
  ASSET_NAME="$1"
  write_native_executable "$DIST_PATH/$ASSET_NAME" "existing"
  printf '%s.version=v1.0.0\n' "$ASSET_NAME" >> "$DIST_PATH/.cfcli-state"
}

write_update_timestamp() {
  ASSET_NAME="$1"
  TIMESTAMP_VALUE="$2"
  printf '%s.update_check=%s\n' "$ASSET_NAME" "$TIMESTAMP_VALUE" >> "$DIST_PATH/.cfcli-state"
}

test_platform() {
  PLATFORM_OS="$1"
  PLATFORM_ARCH="$2"
  PLATFORM_ASSET="$3"
  setup_scenario
  TEST_UNAME_S="$PLATFORM_OS"
  TEST_UNAME_M="$PLATFORM_ARCH"
  export TEST_UNAME_S TEST_UNAME_M

  run_hook

  assert_equals "$HOOK_EXIT" "0"
  assert_file_exists "$DIST_PATH/$PLATFORM_ASSET"
  assert_file_contains "$TEST_CURL_LOG" "releases/latest/download/$PLATFORM_ASSET"
  assert_file_contains "$DIST_PATH/.cfcli-state" "$PLATFORM_ASSET.version=v2.0.0"
  assert_file_contains "$DIST_PATH/.cfcli-state" "$PLATFORM_ASSET.update_check=$TEST_NOW"
  assert_file_not_exists "$DIST_PATH/.cfcli-version"
  assert_file_not_exists "$DIST_PATH/.update-check.ts"
}

run_platform_tests() {
  test_platform MINGW64_NT-10.0 x86_64 cfcli-windows-amd64.exe
  test_platform MINGW64_NT-10.0 aarch64 cfcli-windows-arm64.exe
  test_platform Linux x86_64 cfcli-linux-amd64
  test_platform Linux aarch64 cfcli-linux-arm64
  test_platform Darwin x86_64 cfcli-darwin-amd64
  test_platform Darwin arm64 cfcli-darwin-arm64
}

run_update_tests() {
  setup_scenario
  install_existing_executable cfcli-linux-amd64
  write_update_timestamp cfcli-linux-amd64 "$((TEST_NOW - 1))"
  run_hook
  assert_equals "$HOOK_EXIT" "0"
  assert_file_not_exists "$TEST_CURL_LOG"
  assert_file_contains "$TEST_CFCLI_LOG" "existing"

  setup_scenario
  install_existing_executable cfcli-linux-amd64
  write_update_timestamp cfcli-linux-amd64 "$((TEST_NOW - 57600))"
  TEST_API_RESPONSE='{"tag_name":"v1.0.0"}'
  export TEST_API_RESPONSE
  run_hook
  assert_equals "$HOOK_EXIT" "0"
  assert_equals "$(wc -l < "$TEST_CURL_LOG" | tr -d ' ')" "1"
  assert_file_contains "$TEST_CURL_LOG" "--connect-timeout 5 --max-time 5"

  setup_scenario
  write_update_timestamp cfcli-linux-amd64 "$TEST_NOW"
  run_hook
  assert_equals "$HOOK_EXIT" "0"
  assert_equals "$(wc -l < "$TEST_CURL_LOG" | tr -d ' ')" "2"
  assert_file_contains "$TEST_CURL_LOG" "releases/latest/download/cfcli-linux-amd64"

  setup_scenario
  run_hook
  assert_equals "$HOOK_EXIT" "0"
  TEST_UNAME_S=MINGW64_NT-10.0
  export TEST_UNAME_S
  run_hook
  assert_equals "$HOOK_EXIT" "0"
  assert_file_exists "$DIST_PATH/cfcli-linux-amd64"
  assert_file_exists "$DIST_PATH/cfcli-windows-amd64.exe"
  assert_file_contains "$DIST_PATH/.cfcli-state" "cfcli-linux-amd64.version=v2.0.0"
  assert_file_contains "$DIST_PATH/.cfcli-state" "cfcli-linux-amd64.update_check=$TEST_NOW"
  assert_file_contains "$DIST_PATH/.cfcli-state" "cfcli-windows-amd64.exe.version=v2.0.0"
  assert_file_contains "$DIST_PATH/.cfcli-state" "cfcli-windows-amd64.exe.update_check=$TEST_NOW"
}

run_fallback_tests() {
  setup_scenario
  install_existing_executable cfcli-linux-amd64
  TEST_API_FAIL=1
  export TEST_API_FAIL
  run_hook
  assert_equals "$HOOK_EXIT" "0"
  assert_file_contains "$TEST_CFCLI_LOG" "existing"
  assert_file_contains "$DIST_PATH/.cfcli-state" "cfcli-linux-amd64.update_check=$TEST_NOW"

  setup_scenario
  install_existing_executable cfcli-linux-amd64
  TEST_API_RESPONSE='{"name":"missing tag"}'
  export TEST_API_RESPONSE
  run_hook
  assert_equals "$HOOK_EXIT" "0"
  assert_file_contains "$TEST_CFCLI_LOG" "existing"

  setup_scenario
  install_existing_executable cfcli-linux-amd64
  TEST_DOWNLOAD_FAIL=1
  export TEST_DOWNLOAD_FAIL
  run_hook
  assert_equals "$HOOK_EXIT" "0"
  assert_file_contains "$TEST_CFCLI_LOG" "existing"
  assert_file_contains "$DIST_PATH/.cfcli-state" "cfcli-linux-amd64.version=v1.0.0"

  setup_scenario
  TEST_API_FAIL=1
  export TEST_API_FAIL
  run_hook
  assert_equals "$HOOK_EXIT" "1"
  assert_file_contains "$HOOK_OUTPUT" "CyberFerret CLI is unavailable"

  setup_scenario
  install_existing_executable cfcli-linux-amd64
  write_update_timestamp cfcli-linux-amd64 "$TEST_NOW"
  TEST_CFCLI_EXIT=23
  export TEST_CFCLI_EXIT
  run_hook
  assert_equals "$HOOK_EXIT" "23"
  assert_file_contains "$HOOK_OUTPUT" "Commit is not allowed"
  assert_file_contains "$TEST_CFCLI_LOG" "--mode=quick"
  assert_file_contains "$TEST_CFCLI_LOG" "$EXPECTED_REPO_PATH"
  assert_file_contains "$TEST_CFCLI_LOG" "$EXPECTED_REPO_PATH/.git/cf_files.list"

  setup_scenario
  TEST_UNAME_M=riscv64
  export TEST_UNAME_M
  run_hook
  assert_equals "$HOOK_EXIT" "1"
  assert_file_not_exists "$TEST_CURL_LOG"
}

run_repository_tests() {
  assert_file_not_exists "$PROJECT_ROOT/cyberferret-dist/cyberferret-cli.jar"
  git -C "$PROJECT_ROOT" check-ignore -q cyberferret-dist/.cfcli-version ||
    fail "Expected .cfcli-version to be ignored"
  git -C "$PROJECT_ROOT" check-ignore -q cyberferret-dist/.update-check.ts ||
    fail "Expected .update-check.ts to be ignored"
  git -C "$PROJECT_ROOT" check-ignore -q cyberferret-dist/.cfcli-state ||
    fail "Expected .cfcli-state to be ignored"
  git -C "$PROJECT_ROOT" check-ignore -q cyberferret-dist/cfcli-linux-amd64 ||
    fail "Expected Linux executable to be ignored"
  git -C "$PROJECT_ROOT" check-ignore -q cyberferret-dist/cfcli-linux-arm64 ||
    fail "Expected Linux ARM64 executable to be ignored"
  git -C "$PROJECT_ROOT" check-ignore -q cyberferret-dist/cfcli-windows-amd64.exe ||
    fail "Expected Windows executable to be ignored"
  git -C "$PROJECT_ROOT" check-ignore -q cyberferret-dist/cfcli-windows-arm64.exe ||
    fail "Expected Windows ARM64 executable to be ignored"
  git -C "$PROJECT_ROOT" check-ignore -q cyberferret-dist/cfcli-darwin-amd64 ||
    fail "Expected macOS amd64 executable to be ignored"
  git -C "$PROJECT_ROOT" check-ignore -q cyberferret-dist/cfcli-darwin-arm64 ||
    fail "Expected macOS executable to be ignored"
}

GROUP="${1:-all}"
case "$GROUP" in
  platform) run_platform_tests ;;
  update) run_update_tests ;;
  fallback) run_fallback_tests ;;
  repository) run_repository_tests ;;
  all)
    run_platform_tests
    run_update_tests
    run_fallback_tests
    run_repository_tests
    ;;
  *) fail "Unknown test group: $GROUP" ;;
esac

printf 'PASS: %s\n' "$GROUP"
