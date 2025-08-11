# Issue 7: The `sed -i ''` command is not portable to GNU/Linux

## Description
In the `finishOutputIndexHtml` function, a script uses `sed -i '' ...` to perform an in-place edit of an HTML file. This syntax is specific to BSD/macOS `sed`. On GNU/Linux systems, the `-i` option does not expect a mandatory argument for the backup extension, so this command will fail.

## Code Snippet (from `finishOutputIndexHtml`)
```bash
  sed -i '' -e "s#<!-- IMAGES -->#${imagesHtml}#" "$outputIndexHtml"
```

## Recommendation
To make the in-place edit portable, the script should either detect the type of `sed` available or use a more portable method, such as writing the output to a temporary file and then moving it to replace the original.

Example portable fix:
```bash
  # sed -i '' -e "s#<!-- IMAGES -->#${imagesHtml}#" "$outputIndexHtml" # Not portable
  tmpfile=$(mktemp)
  sed "s#<!-- IMAGES -->#${imagesHtml}#" "$outputIndexHtml" > "$tmpfile" && mv "$tmpfile" "$outputIndexHtml"
```
Alternatively, a check for the `sed` version can be implemented to use the correct syntax for each platform.
