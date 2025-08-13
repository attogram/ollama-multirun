# Issue 1: Script requires Bash v3.2+ but does not check for it

## Description
The `multirun.sh` script uses features that require Bash version 3.2 or higher (e.g., the `=~` operator in `setModels`). However, the script does not check the user's Bash version, which can lead to unexpected errors on systems with older Bash versions.

## Recommendation
Add a check at the beginning of the script to ensure that the Bash version is at least 3.2. If the version is too old, the script should print an error message and exit.

Example implementation:
```bash
if [ -z "$BASH_VERSION" ] || ! (echo "$BASH_VERSION" | awk -F. '{exit !($1 > 3 || ($1 == 3 && $2 >= 2))}') ; then
  echo "Error: This script requires Bash version 3.2 or higher." >&2
  exit 1
fi
```
