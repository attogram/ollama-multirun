# Issue 10: The `safeString` function is inefficient

## Description
The `safeString` function sanitizes an input string by performing several transformations (truncating, lowercasing, replacing characters). Each transformation is done using a separate command and a pipe (`echo ... | tr ...`, `echo ... | sed ...`), which creates multiple subprocesses and is inefficient for simple string operations.

## Code Snippet (from `safeString`)
```bash
  input=${input:0:length} # Truncate to first LENGTH characters
  input=$(echo "$input" | tr '[:upper:]' '[:lower:]') # Convert to lowercase
  input=${input// /_} # Replace spaces with underscores
  input=$(echo "$input" | sed 's/[^a-zA-Z0-9_]/_/g' | tr -cd 'a-zA-Z0-9_') # Replace non-allowed characters with underscores
```

## Recommendation
The string sanitization can be made more efficient by using Bash's built-in parameter expansion features and combining `sed` and `tr` into a single `sed` call.

Example refactoring:
```bash
  local input="$1"
  local length="${2:-40}"
  # Truncate
  input=${input:0:length}
  # Convert to lowercase (Bash 4+)
  input=${input,,}
  # Replace spaces and non-allowed characters
  input=$(echo "$input" | sed 's/ /_/g; s/[^a-zA-Z0-9_]/_/g')
  echo "$input"
```
Note: `tr -cd 'a-zA-Z0-9_'` was redundant and has been removed. The `sed` command now handles all replacements.
