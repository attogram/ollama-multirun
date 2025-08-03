#!/usr/bin/env bash
# usage: ./test-prompts/code/review.[script].sh | ./multirun.sh

name="toolshed.sh"
file="../ollama-bash-toolshed/toolshed.sh"

echo "Act as an expert Software Engineer."
echo "Do a code review of this $name script:"
echo
cat "$file"
