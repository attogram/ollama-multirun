#!/usr/bin/env bash

NAME="run.test.prompts"
VERSION="0.3"

TIMEOUT="300" # number of seconds to allow model to respond
modelsList=""
resultsDirectory="results"
promptDirectory=""

usage() {
  me=$(basename "$0")
  #echo "$NAME"; echo
  echo "Usage:"
  echo "  ./$me [flags] [dir]"
  echo; echo "Flags:";
  echo "  -h       -- Help for $NAME"
  echo "  -m model1,model2  -- Use specific models (comma separated list)"
  echo "  -r <dir> -- Set results directory"
  echo "  -t #     -- Set timeout, in seconds"
  echo "  -v       -- Show version information"
  echo "  [dir]    -- Set the prompt directory"
}

parseCommandLine() {
  while (( "$#" )); do
    case "$1" in
      -h)
        usage
        exit 0
        ;;
      -m) # specify models to run
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
          modelsList=$2
          shift 2
        else
          echo "Error: Argument for $1 is missing" >&2
          exit 1
        fi
        ;;
      -r) # specify results outputDirectory
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
          resultsDirectory=$2
          shift 2
        else
          echo "Error: Argument for $1 is missing" >&2
          exit 1
        fi
        ;;
      -t) # specify timeout in seconds
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
          TIMEOUT=$2
          shift 2
        else
          echo "Error: Argument for $1 is missing" >&2
          exit 1
        fi
        ;;
      -v)
        echo "$NAME v$VERSION"
        exit 0
        ;;
      -*|--*=) # unsupported flags
        echo "Error: unsupported argument: $1" >&2
        exit 1
        #shift 1
        ;;
      *) # preserve positional arguments
        promptDirectory+="$1"
        shift
        ;;
    esac
  done
  # set positional arguments in their proper place
  eval set -- "$promptDirectory"
}

parseCommandLine "$@"

echo "$NAME v$VERSION"; echo

if [ -z "$promptDirectory" ]; then
  echo "ERROR: No Prompt Directory"; echo
  usage
  exit
fi

realPromptDirectory=$(realpath "$promptDirectory" 2>/dev/null)

if [ ! -d "$realPromptDirectory" ]; then
  echo "ERROR: Prompt Directory Not Found: $promptDirectory"; echo
  echo "ERROR: Prompt Directory Not Found: real: $realPromptDirectory"; echo
  usage
  exit
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
parent_dir="$(dirname "$script_dir")"
cd "$parent_dir" || exit 1

echo "Current directory: $(pwd)"
echo "Prompt directory: $realPromptDirectory"
echo "modelsList      : -m $modelsList"
echo "resultsDirectory: -r $resultsDirectory"
echo "TIMEOUT         : -t $TIMEOUT"

if [ ! -x multirun.sh ]; then
    echo "Error: multirun.sh not found or not executable in the parent directory."
    exit 1
fi

txt_files=(${realPromptDirectory}/*.txt) # Get all .txt files in the prompt directory
if [ ${#txt_files[@]} -eq 0 ]; then
  echo "No .txt files found in the prompt directory."
  exit 1
fi

echo "Found ${#txt_files[@]} .txt files in the prompt directory:"
for f in "${txt_files[@]}"; do
    echo "$f"
done

# Loop through each .txt file and run the ollama-multirun command
for file in "${txt_files[@]}"; do
  echo; echo "Prompt: $file"
  ./multirun.sh -r "$resultsDirectory" < "$file"
done

echo; echo "Done."
