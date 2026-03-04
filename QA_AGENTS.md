# How to test the functionality

1. Ask administrator/user where to create new temp folder
2. Go to temp folder
3. Create temp git-repository there
4. Create following test files in the repository:
   * echo "one" > one.file
   * echo "two" > "two two.file"
   * echo "three" > subfolder/three.file
   * echo "four" > "subfolder with spaces/four with space.file"
5. Add all these files into git staged files
6. Do commit: git commit -m "fake commit"
7. Ensure commited is passed successfully
8. Now create following test files in the repository:
   * echo "pat_xxx" > secret.file
9. Add file into git staged files
10. Do commit: git commit -m "fake2 commit"
11. Ensure commit is failed
12. Do commit: git commit -m "fake2 commit, @skip_cf"
13. Ensure commit is passed successfully