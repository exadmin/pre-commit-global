# About

The main aim of this project is to call "https://pre-commit.com/" hooks without necessity of calling installation of
the framework for each cloned repository.

The approach is based on global Git-hooks scripts. Generally it may be useful for teams who work
with a lot of repositories with similar rules to perform checks on commit.

The logic of solution is following:
1. Global hooks are registered once for the Git application
2. Each time user commits - Global Hooks are triggered:
   1. First of all online updates are checked for the Global Hooks
   2. If working repository contains ".pre-commit-config.yaml" file then "pre-commit" framework
   will be started using this configuration.
   3. In case no errors happened on the previous step (or no configuration file is found) then local hook
   ".git/pre-commit" will be called if exists.
4. If other type (then pre-commit) of git-event is happened and local hook-file exists - then it will be called.

## How to install

Use the [Qubership developer installer][developer-installer] to install the complete baseline toolset. To install only
the global hooks, follow the manual setup instructions below.

### Prerequisites

#### curl

Install `curl` and ensure it is available on `PATH`. The commit hook uses it to check GitHub Releases and download the
platform-specific CyberFerret CLI.

#### Git

Install Git from [the Git installation page](https://git-scm.com/install/).

Check whether a global hooks path is already configured:

```sh
git config --global core.hooksPath
# or
git config --global --list
```

If a global hooks path is already configured, decide whether to replace it or make the existing hooks delegate to this
project.

#### CyberFerret password

Obtain the CyberFerret dictionary password from the dictionary owner. Configure the password as the
`CYBER_FERRET_PASSWORD` operating-system environment variable so CyberFerret can decrypt the signature dictionary.

### Repository setup

To trigger the CyberFerret check, add a `.qubership/grand-report.json` file to the target repository.
CyberFerret uses this file to store ignored false-positive signatures. An empty JSON object is sufficient when the file
serves only as a marker for the hooks.

The hook supports Windows on AMD64, Linux on AMD64, and macOS on ARM64. It downloads the matching native CyberFerret CLI
when needed and checks for a newer release at most once every 16 hours. If the update service is unavailable, the hook
continues with the installed executable. Update timestamps and installed versions are tracked separately for each
platform asset in `cyberferret-dist/.cfcli-state`.

#### Staged changes

The commit hook extracts added lines from `git diff --cached --unified=0` and scans them with the existing cfcli
`--mode=quick`. For a replacement, it scans the entire new line. Deleted lines, unchanged context, and unstaged
changes are omitted. This also works before the first commit.

The hook creates a temporary directory named `cf-scan.XXXXXX` inside the repository and passes only its `temp.patch`
file to cfcli through a file list. It removes the directory after the check, including when cfcli rejects the commit.
If Git ignore rules hide the scan file, the hook stops the commit instead of silently skipping the scan.

Findings refer to the temporary file and its line numbers. Original file and extension exclusions do not carry over
to the extracted text. Added lines from separate blocks and files are concatenated, so multiline signatures can match
across their boundaries. Binary changes contain no added text lines and are not analyzed by this check.

#### Pin the CyberFerret CLI version

To pin a specific release, create `.qubership/cfcli.properties` in the repository root and commit it:

```properties
version=v1.2.3
version-sha256=<SHA-256 of the release binary for your platform>
```

Replace `v1.2.3` with the exact release tag and the hash placeholder with the SHA-256 of the binary for your OS and
architecture. Both properties are required. `version` selects a release tag, rather than a Git commit SHA.
The `version-sha256` value accepts 64 hexadecimal characters, with or without the `sha256:` prefix:

```properties
version=v1.2.3
version-sha256=sha256:<SHA-256 of the release binary for your platform>
```

To set a personal default for repositories, put the same settings in `~/.qubership/cfcli.properties`.
The hook selects a version in this order:

1. Use `.qubership/cfcli.properties` from the repository if it is valid.
2. If the repository file is missing, unreadable, or invalid, use `~/.qubership/cfcli.properties` if it is valid.
3. If neither file is valid, use the latest-release update behavior described above.

Blank lines, `#` or `!` comments, surrounding whitespace, and Windows line endings are supported. Duplicate required
properties and lines without `=` are invalid. Tags can contain ASCII letters, digits, dots, underscores, and hyphens,
but cannot be `.` or `..`. The hash must match the platform binary: binaries for different platforms have different
hashes, so one pinned configuration cannot validate binaries for multiple platforms.

Pinned binaries are cached in `~/.qubership/cfcli/<tag>/<platform-asset>`, shared across repositories. The hook checks
the SHA-256 before each use and downloads the tagged release if the cached binary is missing or fails verification.
SHA-256 verification requires `sha256sum` or `shasum`. If downloading, verifying, or installing a pinned binary fails,
the hook falls back directly to the existing latest-release behavior. It does not try the personal default after a
valid repository pin fails to download or pass verification. A scanner failure still blocks the commit.

The hook prints the selected version, the full path of the binary it runs, and a `Reason:` line explaining whether
the version came from the repository settings, personal settings, or latest-release fallback. The latest-release
cache remains in `cyberferret-dist`; its version is reported as `unknown` if its state file has no version entry.
To return a repository to latest-release selection, remove its pin and any personal default that would apply.

### Install global hooks manually

The registration scripts configure the cloned repository's `hooks-global` directory as Git's global hooks path. Keep
the clone in a stable location. If you move or rename it, run the registration script again from its new location.

#### Windows

Open Command Prompt in the directory where you want to create the clone, then run:

```bat
set "FOLDER_NAME=git-global-hooks"
git clone https://github.com/exadmin/pre-commit-global.git "%FOLDER_NAME%"
cd /d "%FOLDER_NAME%"
win_register_this_folder_as_global_hooks.cmd
git config --global core.hooksPath
```

The final command prints a path similar to:

```text
C:\path\to\git-global-hooks\hooks-global
```

#### Linux

Open a terminal in the directory where you want to create the clone, then run:

```sh
FOLDER_NAME=git-global-hooks
git clone https://github.com/exadmin/pre-commit-global.git "$FOLDER_NAME"
cd "$FOLDER_NAME"
./linux_register_this_folder_as_global_hooks.sh
git config --global core.hooksPath
```

The final command prints a path similar to:

```text
/path/to/git-global-hooks/hooks-global
```

Git now calls the global hooks whenever you commit:

```sh
git commit -m "Commit description"
```

## How to remove

Run the matching unregistration script from the cloned repository.

### Windows

```bat
cd /d "C:\path\to\git-global-hooks"
win_unregister_this_folder_as_global_hooks.cmd
```

### Linux

```sh
cd /path/to/git-global-hooks
./linux_unregister_this_folder_as_global_hooks.sh
```

[developer-installer]: https://github.com/Netcracker/qubership-ai-agent-telemetry/blob/main/global-scripts/README.md
