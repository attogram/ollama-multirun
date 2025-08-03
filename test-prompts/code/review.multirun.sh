#!/usr/bin/env bash
# usage: ./test-prompts/code/review.[script].sh | ./multirun.sh

name="multirun.sh"
file="./multirun.sh"

echo "Act as an expert Software Engineer."
echo "Do a critical code review of this $name script:"
echo
cat "$file"

