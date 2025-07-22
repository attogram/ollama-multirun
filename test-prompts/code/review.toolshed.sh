#!/usr/bin/env bash
# usage: ./test-prompts/code/review.[script].sh | ./multirun.sh

name="toolshed.sh"
file="../ollama-bash-toolshed/toolshed.sh"

echo "This is the $name Bash script."
echo "Act as an expert Software Engineer."
echo "Do a full code review of this script:"
echo
cat "$file"
