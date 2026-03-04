# How to test the functionality

1. Ask administrator/user where to create new temp folder
2. Go to temp folder
3. Ensure the working directory is the temp repository (run `cd <temp_repo>` and execute all commands only there)
4. Create temp git-repository there
5. Add following files to the repository:
   * echo "{}" > ./qubership/grand-report.json
6. Create following test files in the repository:
   * echo "one" > one.file
   * echo "two" > "two two.file"
   * echo "three" > subfolder/three.file
   * echo "four" > "subfolder with spaces/four with space.file"
7. Add all these files into git staged files
8. Do commit: git commit -m "fake commit"
9. Ensure commited is passed successfully
10. Now create following test files in the repository:
   * echo "pat_xxx" > secret.file
11. Add file into git staged files
12. Do commit: git commit -m "fake2 commit"
13. Ensure commit is failed
14. Do commit: git commit -m "fake2 commit, @skip_cf"
15. Ensure commit is passed successfully
