# Issue 6: The script uses `expect` but does not check if it's installed

## Description
The `clearModel` function uses the `expect` command to interact with `ollama run`. However, `expect` is not a standard utility and may not be installed on the user's system. The script does not check for the presence of `expect` before calling it, which would lead to a "command not found" error.

## Code Snippet (from `clearModel`)
```bash
  (
    expect \
    -c "spawn ollama run $1" \
...
```

## Recommendation
Add a check at the beginning of the script or within the `clearModel` function to verify that the `expect` command is available in the system's `PATH`. If it's not found, the script should print an informative error message. The `clearModel` function could be disabled or the script could exit.

Example check:
```bash
if ! command -v expect >/dev/null 2>&1; then
  echo "Error: 'expect' command not found. The clearModel function requires 'expect' to be installed." >&2
  # Decide whether to exit or just disable the feature
  # exit 1;
fi
```
