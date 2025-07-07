#!/usr/bin/env bash

echo "Ollama Multirun Test Prompts v0.2"
echo


prompt_dir=$(realpath "$1")

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
parent_dir="$(dirname "$script_dir")"
cd "$parent_dir" || exit 1

echo "Current directory: $(pwd)"
#echo "Script directory: $script_dir"
echo "Prompt directory: $prompt_dir"

if [ ! -x multirun.sh ]; then
    echo "Error: multirun.sh not found or not executable in the parent directory."
    exit 1
fi

#echo -n "multirun: "; ls -al multirun.sh

txt_files=(${prompt_dir}/*.txt) # Get all .txt files in the prompt directory
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
  ./multirun.sh < "$file"
done

echo; echo "Done."
