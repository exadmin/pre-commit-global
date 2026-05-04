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
   * echo "Password1" > pass.txt
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
9. Call "echo '{}' > .qubership/grand-report.json"
10. Do "echo 'ttt' > ttt.txt'"
11. Add ttt.txt file into staged
12. Do commit with message "ttt is added"
13. Ensure commit is passed successfully
14. Ensure no other files then "ttt.txt", "hello.txt", ".qubership/grand-report.json" and ".git" exist in the REPO2 directory
15. Ensure file REPO1/.git/worktrees/cf_files.list exist with content "ttt.txt"
