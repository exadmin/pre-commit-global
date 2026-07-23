# Native CyberFerret updater implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Java CyberFerret invocation with a self-updating native executable on Windows AMD64, Linux AMD64,
and macOS ARM64.

**Architecture:** Keep the hook operation order intact and add small shell functions inside `commit-msg-addon` for
platform selection, throttled release lookup, atomic download, and fallback. Exercise the public hook behavior with a
shell test harness that replaces external commands through `PATH` and uses isolated Git configuration.

**Tech Stack:** POSIX shell, Git, curl, standard Unix tools, and Git Bash on Windows.

## Global constraints

- Preserve the existing local-hook delegation, skip flags, repository marker check, changed-file collection, and
  operation order.
- Use `cprint` for every new console message and `${CYAN}` for normal messages.
- Keep the native CLI arguments as `<repository-path> <changed-files-list-path>`.
- Limit the GitHub API request with `curl --connect-timeout 5 --max-time 5`.
- Do not add a transfer timeout to the asset download.
- Do not check GitHub more than once per 16 hours unless the executable is missing.
- Continue with an existing executable after API, parsing, or download failures.
- Support Windows AMD64, Linux AMD64, and macOS ARM64.

---

### Task 1: Add the native updater behavior tests

**Files:**

- Create: `tests/commit-msg-addon-native-test.sh`

**Interfaces:**

- Consumes: `hooks-global/commit-msg-addon` as an executable shell hook.
- Produces: an isolated test harness whose scenarios invoke the real hook with controlled `curl`, `uname`, and
  CyberFerret behavior.

- [ ] **Step 1: Create the test harness and first failing platform-selection test**

Create a temporary test root, repository, hooks directory, distribution directory, fake-command directory, and Git
global configuration. Copy `commit-msg-addon` into the hooks fixture. Configure `core.hooksPath`, create
`.qubership/grand-report.json`, create a commit-message file, and stage one changed file.

The fake `uname` must return values selected by `TEST_UNAME_S` and `TEST_UNAME_M`. The fake `curl` must append all
arguments to `TEST_CURL_LOG`, return `{"tag_name":"v2.0.0"}` for the API request, and copy a fake executable to the
argument following `--output` for a download request. The downloaded executable must record its two arguments in
`TEST_CFCLI_LOG` and exit with `TEST_CFCLI_EXIT`.

Add scenarios that assert these mappings:

```text
MINGW64_NT-10.0 + x86_64 -> cfcli-windows-amd64.exe
Linux + x86_64           -> cfcli-linux-amd64
Darwin + arm64           -> cfcli-darwin-arm64
```

Each scenario must assert that the curl log contains the expected latest-release asset URL, the downloaded executable
exists in `cyberferret-dist`, `.cfcli-version` contains `v2.0.0`, and `.update-check.ts` contains an integer.

- [ ] **Step 2: Run the platform-selection tests and verify that they fail**

Run:

```sh
bash tests/commit-msg-addon-native-test.sh platform
```

Expected: FAIL because `commit-msg-addon` still searches for `cyberferret-cli.jar` and invokes Java.

- [ ] **Step 3: Add failing throttle and update tests**

Add scenarios with controlled timestamps that verify:

1. A timestamp less than 57,600 seconds old suppresses the API call when the executable exists.
2. A timestamp exactly 57,600 seconds old permits the API call.
3. A missing executable permits the API call even with a fresh timestamp.
4. An unchanged `tag_name` skips the asset download.
5. A newer `tag_name` downloads and replaces the executable.
6. The API call includes `--connect-timeout 5 --max-time 5`.
7. The asset download does not include `--max-time` or `--connect-timeout`.

Use a fake `date` command controlled by `TEST_NOW` so boundary behavior is deterministic.

- [ ] **Step 4: Run the throttle and update tests and verify that they fail**

Run:

```sh
bash tests/commit-msg-addon-native-test.sh update
```

Expected: FAIL because no native update state or API check exists.

- [ ] **Step 5: Add failing fallback and invocation tests**

Add scenarios that verify:

1. API failure updates `.update-check.ts` and runs the existing executable.
2. Malformed API JSON updates `.update-check.ts` and runs the existing executable.
3. Download failure preserves and runs the existing executable.
4. Any failure blocks the commit when no executable exists.
5. The native executable receives the exact repository path and `cf_files.list` path as separate arguments.
6. Native exit code `23` becomes the hook exit code and prints `Commit is not allowed`.
7. An unsupported architecture blocks the commit before invoking curl.

- [ ] **Step 6: Run the fallback tests and verify that they fail**

Run:

```sh
bash tests/commit-msg-addon-native-test.sh fallback
```

Expected: FAIL because the Java implementation has none of the native fallback behavior.

- [ ] **Step 7: Commit the failing tests**

```sh
git add tests/commit-msg-addon-native-test.sh
git commit -m "test: cover native CyberFerret updater"
```

### Task 2: Implement native selection, update, fallback, and invocation

**Files:**

- Modify: `hooks-global/commit-msg-addon`

**Interfaces:**

- Consumes: `uname -s`, `uname -m`, `date +%s`, GitHub Releases API JSON, and the two state files in
  `cyberferret-dist`.
- Produces: `select_cfcli_asset`, `should_check_for_update`, `check_for_cfcli_update`, and direct native CLI invocation.

- [ ] **Step 1: Implement platform selection**

Add `select_cfcli_asset` before the main hook flow. Normalize `uname` values through `case`, set `CFCLI_ASSET`, and
return nonzero for unsupported combinations:

```sh
select_cfcli_asset() {
  OS_NAME="$(uname -s)"
  ARCH_NAME="$(uname -m)"

  case "${OS_NAME}:${ARCH_NAME}" in
    MINGW*:*|MSYS*:*|CYGWIN*:*)
      case "$ARCH_NAME" in
        x86_64|amd64) CFCLI_ASSET="cfcli-windows-amd64.exe" ;;
        *) return 1 ;;
      esac
      ;;
    Linux:x86_64|Linux:amd64)
      CFCLI_ASSET="cfcli-linux-amd64"
      ;;
    Darwin:arm64|Darwin:aarch64)
      CFCLI_ASSET="cfcli-darwin-arm64"
      ;;
    *)
      return 1
      ;;
  esac
}
```

- [ ] **Step 2: Implement the 16-hour decision**

Use `UPDATE_CHECK_INTERVAL=57600`. `should_check_for_update` must return success when the executable is absent, the
timestamp is absent or nonnumeric, the clock moved backwards, or the timestamp age is at least the interval:

```sh
should_check_for_update() {
  [ ! -f "$CFCLI_PATH" ] && return 0
  [ ! -f "$UPDATE_CHECK_TIMESTAMP_PATH" ] && return 0

  LAST_UPDATE_CHECK="$(cat "$UPDATE_CHECK_TIMESTAMP_PATH" 2>/dev/null)"
  case "$LAST_UPDATE_CHECK" in
    ''|*[!0-9]*) return 0 ;;
  esac

  UPDATE_CHECK_AGE=$((CURRENT_TIME - LAST_UPDATE_CHECK))
  [ "$UPDATE_CHECK_AGE" -lt 0 ] && return 0
  [ "$UPDATE_CHECK_AGE" -ge "$UPDATE_CHECK_INTERVAL" ]
}
```

- [ ] **Step 3: Implement API lookup and atomic installation**

`check_for_cfcli_update` must call:

```sh
curl --silent --show-error --fail --location \
  --connect-timeout 5 --max-time 5 \
  "https://api.github.com/repos/exadmin/CyberFerret/releases/latest"
```

Immediately after the attempt, write `CURRENT_TIME` to `.update-check.ts`. Extract one JSON string value for `tag_name`
with `sed`. When the tag differs or the binary is absent, download with:

```sh
curl --silent --show-error --fail --location \
  --output "$CFCLI_TEMP_PATH" \
  "https://github.com/exadmin/CyberFerret/releases/latest/download/$CFCLI_ASSET"
```

On success, run `chmod +x "$CFCLI_TEMP_PATH"`, move it to `CFCLI_PATH`, and write the tag to `.cfcli-version`. Install
cleanup with a trap or explicit removal so failed temporary downloads never replace the active executable.

- [ ] **Step 4: Replace the Java invocation**

Replace `JAR_PATH`, the Java classpath command, and `eval` with:

```sh
DIST_PATH="${GLOBAL_HOOKS_PATH}/../cyberferret-dist"
CFCLI_PATH="${DIST_PATH}/${CFCLI_ASSET}"
VERSION_PATH="${DIST_PATH}/.cfcli-version"
UPDATE_CHECK_TIMESTAMP_PATH="${DIST_PATH}/.update-check.ts"
CURRENT_TIME="$(date +%s)"

if should_check_for_update; then
  check_for_cfcli_update
fi

if [ ! -f "$CFCLI_PATH" ]; then
  cprint "${RED}" "CyberFerret CLI is unavailable at ${CFCLI_PATH}. The commit cannot be checked."
  exit 1
fi

cprint "${CYAN}" "Calling ${CFCLI_PATH} ${REPO_PATH} ${TEMP_FILES_LIST}"
"$CFCLI_PATH" "$REPO_PATH" "$TEMP_FILES_LIST"
CMD_EXIT_CODE=$?
```

Use `cprint "${ORANGE}"` for recoverable API, parsing, and download warnings. Preserve the existing commit rejection
messages and exit-code handling.

- [ ] **Step 5: Run each focused test group**

Run:

```sh
bash tests/commit-msg-addon-native-test.sh platform
bash tests/commit-msg-addon-native-test.sh update
bash tests/commit-msg-addon-native-test.sh fallback
```

Expected: every group reports PASS.

- [ ] **Step 6: Run shell syntax validation**

Run:

```sh
sh -n hooks-global/commit-msg-addon
sh -n tests/commit-msg-addon-native-test.sh
```

Expected: both commands exit with code 0 and print no output.

- [ ] **Step 7: Commit the implementation**

```sh
git add hooks-global/commit-msg-addon
git commit -m "feat: run self-updating native CyberFerret CLI"
```

### Task 3: Remove Java packaging and update installation documentation

**Files:**

- Modify: `.gitignore`
- Modify: `README.md`
- Delete: `cyberferret-dist/cyberferret-cli.jar`

**Interfaces:**

- Consumes: the runtime state and executable names from Task 2.
- Produces: installation documentation without a Java prerequisite and ignored runtime updater artifacts.

- [ ] **Step 1: Add a failing repository-cleanliness assertion**

Extend `tests/commit-msg-addon-native-test.sh` with a `repository` group that asserts:

```sh
test ! -f cyberferret-dist/cyberferret-cli.jar
git check-ignore -q cyberferret-dist/.cfcli-version
git check-ignore -q cyberferret-dist/.update-check.ts
git check-ignore -q cyberferret-dist/cfcli-linux-amd64
git check-ignore -q cyberferret-dist/cfcli-windows-amd64.exe
git check-ignore -q cyberferret-dist/cfcli-darwin-arm64
```

- [ ] **Step 2: Run the repository test and verify that it fails**

Run:

```sh
bash tests/commit-msg-addon-native-test.sh repository
```

Expected: FAIL because the JAR remains and native runtime artifacts are not ignored.

- [ ] **Step 3: Remove the JAR and ignore downloaded artifacts**

Delete `cyberferret-dist/cyberferret-cli.jar`. Append these repository-root patterns to `.gitignore`:

```gitignore
# CyberFerret native runtime
/cyberferret-dist/.cfcli-version
/cyberferret-dist/.update-check.ts
/cyberferret-dist/cfcli-linux-amd64
/cyberferret-dist/cfcli-windows-amd64.exe
/cyberferret-dist/cfcli-darwin-arm64
```

- [ ] **Step 4: Update the README**

Remove the Java prerequisite. Add `curl` as a prerequisite and state that the commit hook downloads and refreshes the
platform-specific CyberFerret CLI automatically. Document the supported combinations and the 16-hour update interval.

- [ ] **Step 5: Run all automated tests**

Run:

```sh
bash tests/commit-msg-addon-native-test.sh
sh -n hooks-global/commit-msg-addon
sh -n tests/commit-msg-addon-native-test.sh
git diff --check
```

Expected: all test scenarios pass, syntax checks print no output, and `git diff --check` prints no errors.

- [ ] **Step 6: Inspect the final diff**

Run:

```sh
git diff -- .gitignore README.md hooks-global/commit-msg-addon tests/commit-msg-addon-native-test.sh
git status --short
```

Expected: only the planned tracked files, the JAR deletion, and the already known user-owned untracked files appear.

- [ ] **Step 7: Commit documentation and packaging changes**

```sh
git add .gitignore README.md cyberferret-dist/cyberferret-cli.jar
git commit -m "docs: describe native CyberFerret installation"
```

