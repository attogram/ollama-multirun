# Issue 8: The script relies on fragile parsing of external command output

## Description
The script uses a combination of `grep`, `awk`, and `sed` in multiple functions (`setStats`, `setOllamaStats`, `setSystemMemoryStats`, `setModelInfo`) to parse the output of external commands like `ollama`, `top`, and `wmic`. This approach is very fragile and will break if the output format of these commands changes in future versions.

## Code Snippet (from `setStats`)
```bash
  statsTotalDuration=$(grep -oE "total duration:[[:space:]]+(.*)" "$modelStatsTxt" | awk '{ print $NF }')
  statsLoadDuration=$(grep -oE "load duration:[[:space:]]+(.*)" "$modelStatsTxt" | awk '{ print $NF }')
...
```

## Recommendation
While this is a larger architectural issue, improvements can be made:
1.  **Use JSON Output**: If the `ollama` command supports JSON output (e.g., via a `--json` flag), the script should use it and parse it with a tool like `jq`. This is much more robust than text parsing.
2.  **Defensive Parsing**: Make the text parsing more defensive. For example, instead of relying on column numbers with `awk`, search for specific keys and then extract the corresponding values.
3.  **Reduce Complexity**: Simplify the command chains where possible.

This is a significant undertaking and might be best addressed as a long-term improvement. For now, documenting this fragility is the first step.
