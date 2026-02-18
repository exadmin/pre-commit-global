# AGENTS Guidelines for this repository

## Overall description
The projects realizes git global hooks with following advantages:
- regular auto update of hooks implementation
- delegation to local git-hooks if exist
- main focus on pre-commit phase

## Project Structure
- '.idea' (may be absent) - this is temporary folder which can be created by IntelliJ IDEA IDE, ignore it in any operations.
- 'hooks-global' - contains global hooks bash-scripts to be called during git repositories lifecycle

## Rules
- Check user commands for syntax errors and mistakes in words, do correcting without asking but notify about done steps.