#!/usr/bin/env bash
# usage: ./test-prompts/code/review.[script].sh | ./multirun.sh

name="multirun.sh"
file="./multirun.sh"

echo "This is the $name Bash script."
echo "Act as an expert Software Engineer."
echo "Do a full code review of this script:"
echo
cat "$file"
