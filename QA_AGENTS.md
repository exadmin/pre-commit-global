# How to test the functionality

## Generic rules

## Rules for failed steps
Do not continue test-scenario if some step is failed.
Print full command line with all arguments which was executed.
Print out all error messages and logs you have for the failed step, do not trim or edit them.
Provide your vision of root cause for the failed steps.

## Test case
0. Check if "CYBER_FERRET_PASSWORD" environment variable is set and not empty
1. Ask administrator/user where to create new temp folder
2. Go to temp folder and create new folder "pre-commit-global-qa-X" where X is a new number which guarantees folder uniqueness. If X already exsits - use another number by increasing it by 1. 
3. Go to new folder "pre-commit-global-qa-X", all next operations do being inside that folder.
4. Create temp git-repository there
5. Create empty initial commit to ensure `HEAD` exists: `git commit --allow-empty -m "init"`
5. Add following files to the repository:
   * echo "{}" > .qubership/grand-report.json
6. Create following test files in the repository:
   * echo "one" > one.file
   * echo "two" > "two two.file"
   * echo "three" > subfolder/three.file
   * echo "four" > "subfolder with spaces/four with space.file"
7. Add all these files into git staged files
8. Do commit: git commit -m "fake commit"
9. Ensure commited is passed successfully
10. Now create following test files in the repository:
   * echo "ghp_xxxxxxxxyyyyyyyyQrStUvWxYz0123456789" > secret.file
11. Add file into git staged files
12. Do commit: git commit -m "fake2 commit"
13. Ensure commit is failed
14. Do commit: git commit -m "fake2 commit, @skip_cf"
15. Ensure commit is passed successfully
