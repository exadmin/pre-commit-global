# How to test the functionality on all operating systems

## Generic rules

Run the test steps one by one in the specified order.

Use commands and path syntax that are native to the current operating system. The instructions describe file-system
operations abstractly when their command syntax differs between Windows, Linux, and macOS.

Prefer using `cmd.exe` batch files instead of PowerShell scripts on Windows.

If a step fails unexpectedly:

- Do not continue the test scenario.
- Print the full command line, including all arguments, that was executed.
- Print all available error messages and logs without trimming or editing them.
- Provide your assessment of the root cause.

Exception: if Test 6 fails on Windows specifically because a generated path exceeds the `MAX_PATH` limit, report the
failure as described above, skip the remaining steps of Test 6, and continue with Test 7. Do not treat any other error
as this exception.

## Test cases

### Preparing for testing

0. Check that the `CYBER_FERRET_PASSWORD` environment variable is set and is not empty.
1. Go to the system temporary directory.
2. Create a directory named `pre-commit-global-qa-?`, where `?` is a number that makes the directory name unique. If
   the directory already exists, increment the number until the name is unique.
3. Go to the new `pre-commit-global-qa-?` directory. This directory is the working directory.
4. Initialize a Git repository there.
5. Create an empty initial commit to ensure that `HEAD` exists: `git commit --allow-empty -m "init"`.
6. Create `.qubership/grand-report.json`, including its parent directory, with exactly this content:

   ```json
   {}
   ```

### Test 1: Sunny-day scenario: good files are committed successfully

1. Create the following test files in the repository:

   - `one.file` with the content `one`.
   - `two two.file` with the content `two`.
   - `subfolder/three.file` with the content `three`.
   - `subfolder with spaces/four with space.file` with the content `four`.

   Create all missing parent directories.
2. Stage all these files.
3. Commit the files: `git commit -m "fake commit"`.
4. Ensure that the commit succeeds.

### Test 2: Files contain bad signatures: the commit must not pass

1. Create `secret.file` in the repository with this content:

   ```text
   ghp_xxxxxxxxyyyyyyyyQrStUvWxYz0123456789
   ```

2. Stage the file.
3. Attempt to commit it: `git commit -m "fake2 commit"`.
4. Ensure that the commit fails.

### Test 3: Checks can be bypassed in a controlled way

1. Commit the already staged file: `git commit -m "fake2 commit, @skip_cf"`.
2. Ensure that the commit succeeds.
3. Create `f1.txt` with the content `hack`.
4. Stage the created file.
5. Commit it: `git commit -m "fake2 commit, @cf_ignore"`.
6. Ensure that the commit succeeds.
7. Create `f2.txt` with the content `hack hack`.
8. Stage the created file.
9. Commit it: `git commit -m "fake2 commit, @cf_skip"`.
10. Ensure that the commit succeeds.
11. Create `f3.txt` with the content `hack hack hack`.
12. Stage the created file.
13. Commit it: `git commit -m "fake2 commit, @ignore_cf"`.
14. Ensure that the commit succeeds.

### Test 4: Dictionary files must not appear in the working directory

1. Ensure that no files matching `*.encrypted` or `*.decrypted` exist in the working directory.

### Test 5: Only staged files are processed during a commit

1. Create the following files in the repository:

   - `hello.file` with the content `hello`.
   - `pass.txt` with the content `paSSw0rd`.

2. Stage only `hello.file`.
3. Commit it: `git commit -m "adding hello.file only commit"`.
4. Ensure that the commit succeeds.
5. Stage `pass.txt`.
6. Attempt to commit it: `git commit -m "adding pass.txt"`. The commit must fail.
7. Delete `pass.txt`.
8. Remove `pass.txt` from the Git index.
9. Ensure that `pass.txt` is not staged.

### Test 6: Commit many files

1. Create 1,000 empty `.txt` files with random 32-character names. Put them into a random five-level directory
   hierarchy whose directory names are also random 32-character strings.

   On Windows, follow these requirements:

   - Do not generate the files with a parenthesized loop passed directly to `cmd.exe /c`. Variable expansion and
     command grouping differ between an interactive command and a batch file.
   - Save the following script as `generate-many-files.cmd` in the working directory, and execute it as a separate
     batch file:

     ```batch
     @echo off
     setlocal EnableExtensions EnableDelayedExpansion

     set "OUTPUT_ROOT=many-files"
     if exist "%OUTPUT_ROOT%" (
       echo The output directory already exists: %OUTPUT_ROOT%
       exit /b 1
     )

     mkdir "%OUTPUT_ROOT%" || exit /b 1

     for /L %%I in (1,1,1000) do (
       set "RELATIVE_PATH=%OUTPUT_ROOT%"

       for /L %%L in (1,1,5) do (
         call :random32 DIRECTORY_NAME
         set "RELATIVE_PATH=!RELATIVE_PATH!\!DIRECTORY_NAME!"
       )

       mkdir "!RELATIVE_PATH!" || exit /b 1

       call :random32 FILE_NAME
       set "FILE_PATH=!RELATIVE_PATH!\!FILE_NAME!.txt"
       if exist "!FILE_PATH!" (
         echo Generated a duplicate file path: !FILE_PATH!
         exit /b 1
       )
       type nul > "!FILE_PATH!" || exit /b 1
     )

     set "FILE_COUNT=0"
     for /F %%C in ('dir /S /B /A-D "%OUTPUT_ROOT%\*.txt" 2^>nul ^| find /C /V ""') do set "FILE_COUNT=%%C"

     if not "!FILE_COUNT!"=="1000" (
       echo Expected 1000 generated files, but found !FILE_COUNT!.
       exit /b 1
     )

     exit /b 0

     :random32
     set "RANDOM_VALUE=00000%RANDOM%00000%RANDOM%00000%RANDOM%00000%RANDOM%"
     set "%~1=%RANDOM_VALUE:~-32%"
     exit /b 0
     ```

   - Ensure that the script exits with code `0`, reports no errors, and creates exactly 1,000 `.txt` files under
     `many-files`.
   - Delete `generate-many-files.cmd` after it succeeds.
   - Do not combine script execution, staging, and committing in one `cmd.exe /c` command. Complete and verify this
     step before proceeding to step 2.
   - If any step of this test fails on Windows with `Filename too long`, `The filename or extension is too long`, or
     another error that clearly identifies the `MAX_PATH` limit as the cause, apply the exception in the generic
     rules: report the failure, skip the remaining steps of Test 6, and continue with Test 7.

2. Stage all the files.
3. Commit them: `git commit -m "lot of files"`.
4. Ensure that the commit succeeds.

### Test 7: Check worktree functionality

1. Go to the system temporary directory.
2. Create a new, uniquely named `REPO1` directory, and initialize a Git repository in it with `git init`.
3. Go to `REPO1`.
4. Create `hello.txt` with the content `hello`.
5. Stage the file.
6. Commit it with the message `initial commit`.
7. Add a worktree in a uniquely named sibling `REPO2` directory: `git worktree add <REPO2-path>`.
8. Go to `REPO2`.
9. Create `.qubership/grand-report.json`, including its parent directory, with exactly this content:

   ```json
   {}
   ```

10. Create `ttt.txt` with the content `ttt`.
11. Stage `ttt.txt`.
12. Commit it with the message `ttt is added`.
13. Ensure that the commit succeeds.
14. Ensure that no entries other than `ttt.txt`, `hello.txt`, `.qubership/grand-report.json`, and `.git` exist in the
    `REPO2` directory.
15. Ensure that `REPO1/.git/worktrees/<REPO2-directory-name>/cf_files.list` exists and contains exactly `ttt.txt`.

### Test 8: Check that multiple signatures can be found in the same file

1. Go to the system temporary directory.
2. Create a new, uniquely named `REPO3` directory, and initialize a Git repository in it with `git init`.
3. Go to `REPO3`.
4. Create `file.txt` with the following exact content and LF line endings:

   ```text
   monitoring.netcracker.com
   some.netcracker.com
   ```

5. Create `.qubership/grand-report.json`, including its parent directory, with exactly this content:

   ```json
   {}
   ```

6. Stage `file.txt`.
7. Attempt to commit it with the message `initial commit`.
8. Ensure that the commit fails and that the console output reports a forbidden signature, including messages like:

   ```text
   ...
   Signature "NC-SUB-DOMAIN" found in file.txt at position 26
   ...
   [QUBERSHIP] Commit is not allowed
   ...
   ```

### Test 9: Check that `git pull` in a worktree hook does not pull the user's repository

1. Go to the system temporary directory.
2. Create a new, uniquely named bare `ORIGIN` Git repository with `git init --bare`.
3. Clone `ORIGIN` into a uniquely named `main` directory.
4. Go to the `main` directory.
5. Create an empty initial commit to ensure that `HEAD` exists: `git commit --allow-empty -m "init"`.
6. Push the current branch to `origin` and set its upstream: `git push -u origin HEAD`.
7. Add a worktree with a new branch in a uniquely named sibling `wt` directory:
   `git worktree add <wt-path> -b feat`.
8. Go to the `wt` directory.
9. Push the current branch to `origin` and set its upstream: `git push -u origin feat`.
10. Get the global hooks path from `git config --global core.hooksPath`. In that directory, replace the content of
    `.last_pull_timestamp` with `0` so that the hooks self-update runs.
11. Create `x.txt` with the content `x`.
12. Stage `x.txt`.
13. Commit it with the message `x`.
14. Push the current branch to `origin`.
15. Soft-reset the current branch: `git reset --soft HEAD~1`.
16. Commit with the message `squash`.
17. Ensure that the commit succeeds.
18. Ensure that `git reflog` does not contain `pull: Fast-forward` immediately after the reset.

### Test 10: Check that global hooks self-update does not corrupt the user's staged index

1. Go to the system temporary directory.
2. Save the current value and the configured or unconfigured state of the global `core.hooksPath` setting. Restore the
   setting to that exact state at the end of this test, regardless of whether the test succeeds or fails.
3. In the system temporary directory, create unique directories named `hooks-origin-?`, `hooks-upstream-?`,
   `hooks-installed-?`, and `user-repo-?`. Refer to their absolute paths as `HOOKS_ORIGIN`, `HOOKS_UPSTREAM`,
   `HOOKS_INSTALLED`, and `USER_REPO`, respectively.
4. Initialize `HOOKS_ORIGIN` as a bare Git repository: `git init --bare <HOOKS_ORIGIN-path>`.
5. Copy (do not clone) the current `pre-commit-global` repository into `HOOKS_UPSTREAM`.
6. Go to `HOOKS_UPSTREAM`.
7. Set `HOOKS_ORIGIN` as the `origin` remote: `git remote set-url origin <HOOKS_ORIGIN-path>`.
8. Push the current branch to `origin` and set its upstream: `git push -u origin HEAD`.
9. Determine the current branch name. Set `HOOKS_ORIGIN`'s `HEAD` symbolic reference to
   `refs/heads/<current-branch-name>` by running `git symbolic-ref` against the bare repository.
10. Clone `HOOKS_ORIGIN` into `HOOKS_INSTALLED`.
11. Ensure that `HOOKS_INSTALLED/hooks-global/pre-commit` exists. On systems that use executable permission bits,
    ensure that it is executable. On all systems, ensure that Git records it as executable.
12. Set the global hooks path to the absolute `HOOKS_INSTALLED/hooks-global` path:
    `git config --global core.hooksPath <installed-hooks-path>`.
13. Go to `HOOKS_UPSTREAM`.
14. Create `self-update-marker.txt` with the content `self-update marker`.
15. Stage `self-update-marker.txt`.
16. Ensure that the `HOOKS_INSTALLED/cyberferret-dist` directory exists. Create it if it does not exist.
17. Commit it with the message `self-update marker`.
18. Push the current branch to `origin`.
19. Initialize `USER_REPO` as a Git repository with `git init`.
20. Go to `USER_REPO`.
21. Create `.qubership/grand-report.json`, including its parent directory, with exactly this content:

    ```json
    {}
    ```

22. Stage `.qubership/grand-report.json`.
23. Commit it with the message `init`.
24. Get the global hooks path from `git config --global core.hooksPath`. In that directory, replace the content of
    `.last_pull_timestamp` with `0` so that the hooks self-update runs.
25. Create `user-file.txt` with the content `user content`.
26. Stage only `user-file.txt`.
27. Ensure that the staged-files list contains exactly `user-file.txt` before the commit.
28. Commit it with the message `user commit`.
29. Ensure that the commit succeeds.
30. Ensure that the last commit contains exactly `user-file.txt`.
31. Ensure that `self-update-marker.txt` does not exist in the `USER_REPO` working directory.
32. Ensure that `self-update-marker.txt` is not staged in `USER_REPO`.
33. Restore the global `core.hooksPath` setting to the exact value and configured or unconfigured state saved in
    step 2.
