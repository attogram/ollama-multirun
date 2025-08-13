# Issue 4: The script uses non-robust methods to check for empty arrays

## Description
The script checks for empty or non-empty arrays using `[ -z "${array[*]}" ]` or `[ -n "${array[*]}" ]`. When an array is empty, `"${array[*]}"` expands to an empty string. However, this can be unreliable depending on `IFS` settings and shell behavior.

## Code Snippet (from `setModels`)
```bash
  if [ -z "${models[*]}" ]; then
    echo "No models found. Please install models with 'ollama pull <model-name>'" >&2
    exit 1
  fi
...
  if [ -n "${parsedModels[*]}" ]; then
    models=("${parsedModels[@]}")
  fi
```

## Recommendation
The most robust way to check for an empty array in Bash is to check its number of elements using `${#array[@]}`.

Example fix:
```bash
  if [ ${#models[@]} -eq 0 ]; then
...
  if [ ${#parsedModels[@]} -gt 0 ]; then
...
```
