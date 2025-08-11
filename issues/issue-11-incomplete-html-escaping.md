# Issue 11: The `textarea` function has incomplete HTML escaping

## Description
The `textarea` function attempts to escape HTML special characters using a `sed` command. However, the escaping is incomplete. It handles `&`, `<`, `>`, `"`, and `'`, but it misses other characters that could be problematic in an HTML context, such as backticks (`` ` ``) or forward slashes (`/`) if the content were to be used inside a script tag.

## Code Snippet (from `textarea`)
```bash
  content=$(echo "$content" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g') # Escape HTML special characters
```

## Recommendation
For robust HTML escaping, it's better to use a more comprehensive approach. While a pure Bash solution can be complex, the existing `sed` command can be extended to include more characters. However, the best practice would be to use a dedicated utility for HTML escaping if one is available.

A slightly improved `sed` command could also handle backticks:
```bash
  content=$(echo "$content" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g; s/`/&#96;/g')
```
For a truly robust solution, a different tool or language (like Python or Perl) that has standard HTML escaping libraries would be preferable to manual escaping in shell.
