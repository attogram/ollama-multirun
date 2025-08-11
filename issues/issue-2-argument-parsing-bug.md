# Issue 2: Command-line prompt arguments are concatenated without spaces

## Description
In the `parseCommandLine` function, when parsing positional arguments for the prompt, the script concatenates them without spaces. For example, if the script is run as `./multirun.sh hello world`, the `prompt` variable becomes "helloworld" instead of "hello world".

## Code Snippet
```bash
      *) # preserve positional arguments
        prompt+="$1"
        shift
        ;;
```

## Recommendation
Modify the line `prompt+="$1"` to include a space between arguments. A simple fix is to change it to `prompt+="$1 "`. A more robust solution would be to collect all positional arguments into an array and then join them with spaces.
