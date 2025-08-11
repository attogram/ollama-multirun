# Issue 3: Model name matching is based on substring search, which can be buggy

## Description
The script uses the `=~` operator to check if a model exists (in `setModels`) or if a model has been found (in `createMainModelIndexHtml`). This performs a substring match, not an exact match. This can lead to incorrect behavior if one model name is a substring of another (e.g., `mistral` and `not-mistral`).

## Code Snippet (from `setModels`)
```bash
      if [[ "${models[*]}" =~ "$m" ]]; then # if model exists
        parsedModels+=("$m")
...
```

## Recommendation
Replace the substring match with an exact match. This can be done by looping through the array of existing models and comparing each one to the target model name.

Example fix:
```bash
      found=0
      for existing_model in "${models[@]}"; do
          if [[ "$existing_model" == "$m" ]]; then
              found=1
              break
          fi
      done
      if [[ $found -eq 1 ]]; then
        parsedModels+=("$m")
...
```
The same logic should be applied in `createMainModelIndexHtml`.
