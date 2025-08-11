# Issue 5: Script fails to handle filenames with spaces when showing images

## Description
The `setStats` function populates the `addedImages` variable with a newline-separated list of image filenames. The `showImages` function then iterates over this variable using an unquoted `for` loop (`for image in ${addedImages}`). This causes word splitting, and filenames containing spaces will be processed incorrectly.

## Code Snippet (from `showImages`)
```bash
  if [ -n "$addedImages" ]; then
    for image in ${addedImages}; do
...
```

## Recommendation
To handle filenames with spaces correctly, the `addedImages` variable should be an array, and the loop in `showImages` should iterate over the quoted array expansion.

1.  **In `setStats`**, populate `addedImages` as an array:
    ```bash
    mapfile -t addedImages < <(grep -oE "Added image '(.*)'" "$modelStatsTxt" | awk '{ print $NF }' | sed "s/'//g")
    ```
2.  **In `showImages`**, iterate over the array correctly:
    ```bash
    if [ ${#addedImages[@]} -gt 0 ]; then
      for image in "${addedImages[@]}"; do
    ...
    ```
