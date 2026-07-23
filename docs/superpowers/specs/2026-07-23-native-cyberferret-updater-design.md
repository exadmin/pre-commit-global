# Native CyberFerret updater design

## Goal

Replace the Java-based CyberFerret CLI invocation in the global `commit-msg` hook with a native executable. Before
running the executable, the hook periodically checks the latest GitHub release and updates the local executable when
needed.

## Scope

The change applies to `hooks-global/commit-msg-addon`. The native CLI keeps the Java CLI argument contract:

```text
<repository-path> <changed-files-list-path>
```

The existing local-hook delegation, skip flags, `.qubership/grand-report.json` marker check, changed-file collection,
and operation order remain unchanged.

## Platform selection

The hook uses `uname` output to select a GitHub release asset and local executable:

| Platform | Architecture | Asset and local filename |
| --- | --- | --- |
| Windows under Git Bash | AMD64 | `cfcli-windows-amd64.exe` |
| Linux | AMD64 | `cfcli-linux-amd64` |
| macOS | ARM64 | `cfcli-darwin-arm64` |

`cfcli-darwin-arm64` is a temporary asset name and can be changed when the CyberFerret release naming is finalized.
An unsupported operating system or architecture produces an error through `cprint` because the hook cannot select a
compatible executable.

## Update check

The hook stores update state in `cyberferret-dist`:

- `.cfcli-version` contains the installed GitHub release tag.
- `.update-check.ts` contains the Unix timestamp of the latest GitHub API check attempt.

The hook checks for an update when `.update-check.ts` is absent, invalid, older than 16 hours, or the selected native
executable is absent. The missing executable condition bypasses the 16-hour interval so the hook can recover from an
incomplete installation.

The check requests the latest release from:

```text
https://api.github.com/repos/exadmin/CyberFerret/releases/latest
```

The API request uses `curl --connect-timeout 5 --max-time 5`. After attempting the API request, the hook writes the
current timestamp to `.update-check.ts`, including when the request fails. This prevents a network outage from adding
delay to every commit.

The hook extracts `tag_name` from a successful response and compares it with `.cfcli-version`. A missing or malformed
tag is treated as a failed update check.

## Download and installation

When the latest tag differs from `.cfcli-version`, or the executable is missing, the hook downloads the platform asset
from the latest-release download URL:

```text
https://github.com/exadmin/CyberFerret/releases/latest/download/<asset-name>
```

The download uses `curl` with redirects enabled and its default transfer timeout. It writes to a temporary file in
`cyberferret-dist`, never directly to the active executable. After a successful download, the hook makes the file
executable where applicable, atomically replaces the active executable, and writes the release tag to
`.cfcli-version`.

A failed download removes only the temporary file and preserves the active executable and version file.

## Failure behavior

GitHub API, response parsing, and download failures produce warnings through `cprint`.

If an existing platform-compatible executable is available after a failure, the hook runs it. If no executable is
available, the hook prints an error and blocks the commit.

The native process is invoked directly without `eval`:

```sh
"$CFCLI_PATH" "$REPO_PATH" "$TEMP_FILES_LIST"
```

The hook preserves the native process exit code. A nonzero exit code blocks the commit and prints the existing
CyberFerret bypass guidance through `cprint`.

## Console output

All new normal, warning, and error messages use `cprint`. Normal status messages use `${CYAN}`. Recoverable update
failures use `${ORANGE}`, and errors that prevent the CyberFerret check use `${RED}`.

## Verification

Automated shell tests provide controlled `curl`, `uname`, and native executable implementations through `PATH`. They
cover:

- Windows AMD64, Linux AMD64, and macOS ARM64 asset selection.
- A missing timestamp and a timestamp older than 16 hours.
- Suppression of the API request within the 16-hour interval.
- A missing executable bypassing the interval.
- Installation of a newer release.
- Reuse of the installed release when the tag is unchanged.
- API timeout, malformed API output, and failed download fallback.
- Commit blocking when no executable is available.
- Direct native invocation with the repository and changed-files-list arguments.
- Propagation of the native executable exit code.

