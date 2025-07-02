#!/usr/bin/env bash

echo "Ollama Multirun Test Prompts v0.1"
echo

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
parent_dir="$(dirname "$script_dir")"
cd "$parent_dir" || exit 1

echo "Current directory: $(pwd)"
echo "Test Prompts directory: $script_dir"

if [ ! -x multirun.sh ]; then
    echo "Error: multirun.sh not found or not executable in the parent directory."
    exit 1
fi

echo -n "multrun: "
ls -al multirun.sh

txt_files=(test-prompts/*.txt) # Get all .txt files in the current directory
if [ ${#txt_files[@]} -eq 0 ]; then
  echo "No .txt files found in the current directory."
  exit 1
fi

echo "Found ${#txt_files[@]} .txt files in the current directory:"
for f in "${txt_files[@]}"; do
    echo "$f"
done

# Loop through each .txt file and run the ollama-multirun command
for file in "${txt_files[@]}"; do
  echo "Prompt: $file"
  ./multirun.sh < "$file"
done

echo
echo "Done."
