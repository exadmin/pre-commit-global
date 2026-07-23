# How to test the functionality

## Generic rules
There is list of test-steps which you need execute one by one.
If step is failed unexpectedly - Do not continue test-scenario if some step is failed
If step is failed unexpectedly - print full command line with all arguments which was executed.
If step is failed unexpectedly - print out all error messages and logs you have for the failed step, do not trim or edit them.
If step is failed unexpectedly - provide your vision of root cause for the failed steps.

## Test cases

### Preparing for testing
0. Check if "CYBER_FERRET_PASSWORD" environment variable is set and not empty
1. Go to "/tmp" folder
2. Create new folder "pre-commit-global-qa-?" where ? is a new number which guarantees folder uniqueness. If ? already exists - use another number by increasing it by 1. 
3. Go to new folder "pre-commit-global-qa-?", let's call it "working folder"
4. Initialize git-repository there
5. Create empty initial commit to ensure `HEAD` exists: `git commit --allow-empty -m "init"`
5. Add following files to the repository:
   * echo "{}" > .qubership/grand-report.json

### Test-1: Sunny-day scenario - good files are committed successfully
1. Create following test files in the repository:
   * echo "one" > one.file
   * echo "two" > "two two.file"
   * echo "three" > subfolder/three.file
   * echo "four" > "subfolder with spaces/four with space.file"
2. Add all these files into git staged files
3. Do commit: git commit -m "fake commit"
4. Ensure commit is passed successfully

### Test-2: There are bad signatures in the files - commit must not pass
1. Now create following test files in the repository:
   * echo "ghp_xxxxxxxxyyyyyyyyQrStUvWxYz0123456789" > secret.file
2. Add file into git staged files
3. Do commit: git commit -m "fake2 commit"
4. Ensure commit is failed

### Test-3: There should be ability to bypass checks in controlled way
1. Do commit: git commit -m "fake2 commit, @skip_cf"
2. Ensure commit is passed successfully

3. Create file "f1.txt" with content inside "hack"
4. Add created file into git staged files
5. Do commit: git commit -m "fake2 commit, @cf_ignore"
6. Ensure commit is passed successfully

7. Create file "f2.txt" with content inside "hack hack"
8. Add created file into git staged files
9. Do commit: git commit -m "fake2 commit, @cf_skip"
10. Ensure commit is passed successfully

11. Create file "f3.txt" with content inside "hack hack hack"
12. Add created file into git staged files
13. Do commit: git commit -m "fake2 commit, @ignore_cf"
14. Ensure commit is passed successfully

### Test-4: Dictionary files must not appear in the working directory
1. Ensure no files like "dictionary-latest-cache.*" exists in the working folder.

### Test-5: Only staged files must be processed during commit
1. Create following files in the repository:
   * echo "hello" > hello.file
   * echo "paSSw0rd" > pass.txt
2. Add only "hello.file" into staged files
3. Do commit: git commit -m "adding hello.file only commit"
4. Ensure commit is passed successfully
5. Add pass.txt to staged files
6. Do commit: git commit -m "adding pass.txt" - this commit must fail.
7. Delete pass.txt

### Test-6: Check commiting lot of files
1. Create 1000 empty *.txt files with long random names (32 chars each) which are put into random hierarchy of folders (folder names are randome too with 32 chars lenght) with deep-level = 5.
2. Add all files into staged
3. Call git-commit for them: git commit -m "lot of files"
4. Ensure every thing is passed successfully


### Test-7: Check worktrees functionality
1. Go to "/tmp" directory
2. Create new REPO1 git repository using "git init"
3. Go inside REPO1
4. Do "echo 'hello' > hello.txt'"
5. Add this file into staged
6. Do commit with message "initial commit"
7. Call "git worktree add ../REPO2"
8. Go to REPO2 folder
9a. Call "mkdir -p .qubership"
9b. Call "echo '{}' > .qubership/grand-report.json"
10. Do "echo 'ttt' > ttt.txt'"
11. Add ttt.txt file into staged
12. Do commit with message "ttt is added"
13. Ensure commit is passed successfully
14. Ensure no other files but "ttt.txt", "hello.txt", ".qubership/grand-report.json" and ".git" exist in the REPO2 directory
15. Ensure file REPO1/.git/worktrees/REPO2/cf_files.list exist with content "ttt.txt"

### Test-8: Check multiple signatures can be found in same file
1. Go to "/tmp" directory
2. Create new REPO3 git repository using "git init"
3. Go inside REPO3
4. Do "echo -e 'monitoring.netcracker.com\nsome.netcracker.com'" > file.txt
5. Call "mkdir -p .qubership"
6. Call "echo '{}' > .qubership/grand-report.json"
7. Add `file.txt` file into staged
8. Do commit with message "initial commit"
9. The commit must fail with messages in the console which show that a forbidden signature was found, like:
```
...
Signature "NC-SUB-DOMAIN" found in file.txt at position 26
...
[QUBERSHIP] Commit is not allowed
...
```

### Test-9: Check git pull in worktree hook does not pull user's repository
1. Go to "/tmp" directory
2. Create new bare ORIGIN git repository using "git init --bare"
3. Clone ORIGIN repository into "main" folder
4. Go inside main folder
5. Create empty initial commit to ensure `HEAD` exists: `git commit --allow-empty -m "init"`
6. Push current branch to origin and set upstream: `git push -u origin HEAD`
7. Add new worktree with new branch: `git worktree add ../wt -b feat`
8. Go inside wt folder
9. Push current branch to origin and set upstream: `git push -u origin feat`
10. Age the throttle so hooks self-update runs: `echo 0 > "$(git config --global core.hooksPath)/.last_pull_timestamp"`
11. Create file "x.txt" with content inside "x"
12. Add x.txt file into staged
13. Do commit with message "x"
14. Push current branch to origin
15. Reset current branch using `git reset --soft HEAD~1`
16. Do commit with message "squash"
17. Ensure commit is passed successfully
18. Ensure `git reflog` does not contain "pull: Fast-forward" right after reset

### Test-10: Check global hooks self-update does not corrupt user's staged index
1. Go to "/tmp" directory
2. Save current global hooks path: `OLD_HOOKS_PATH=$(git config --global core.hooksPath)`. Note - restore global hook path (as described in the end of this test case) in any case: if test fails or passed. 
3. Create new unique folders "hooks-origin-?", "hooks-upstream-?", "hooks-installed-?" and "user-repo-?", let's call them HOOKS_ORIGIN, HOOKS_UPSTREAM, HOOKS_INSTALLED and USER_REPO
4. Create new bare HOOKS_ORIGIN git repository using "git init --bare"
5. Clone current pre-commit-global repository into HOOKS_UPSTREAM folder
6. Go inside HOOKS_UPSTREAM folder
7. Set HOOKS_ORIGIN as "origin" remote: `git remote set-url origin "$HOOKS_ORIGIN"`
8. Push current branch to origin and set upstream: `git push -u origin HEAD`
9. Set HOOKS_ORIGIN HEAD to pushed branch: `git --git-dir="$HOOKS_ORIGIN" symbolic-ref HEAD "refs/heads/$(git branch --show-current)"`
10. Clone HOOKS_ORIGIN repository into HOOKS_INSTALLED folder
11. Ensure "$HOOKS_INSTALLED/hooks-global/pre-commit" file exists and is executable
12. Set global hooks path to installed hooks: `git config --global core.hooksPath "$HOOKS_INSTALLED/hooks-global"`
13. Go inside HOOKS_UPSTREAM folder
14. Create a fast-forward update for installed hooks repository:
    * echo "self-update marker" > self-update-marker.txt
15. Add "self-update-marker.txt" into staged files
16. Do commit with message "self-update marker"
17. Push current branch to origin
18. Create new USER_REPO git repository using "git init"
19. Go inside USER_REPO
20. Call "mkdir -p .qubership"
21. Call "echo '{}' > .qubership/grand-report.json"
22. Add ".qubership/grand-report.json" into staged files
23. Do commit with message "init"
24. Age the throttle so hooks self-update runs: `echo 0 > "$(git config --global core.hooksPath)/.last_pull_timestamp"`
25. Create file "user-file.txt" with content inside "user content"
26. Add only "user-file.txt" into staged files
27. Ensure staged files list contains exactly "user-file.txt" before commit
28. Do commit with message "user commit"
29. Ensure commit is passed successfully
30. Ensure last commit contains exactly "user-file.txt"
31. Ensure "self-update-marker.txt" does not exist in USER_REPO working directory
32. Ensure "self-update-marker.txt" is not staged in USER_REPO
33. Restore previous global hooks path: `git config --global core.hooksPath "$OLD_HOOKS_PATH"`
