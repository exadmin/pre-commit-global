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
continues with the installed executable.

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
