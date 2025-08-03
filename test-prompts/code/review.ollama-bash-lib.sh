#!/usr/bin/env bash
# usage: ./test-prompts/code/review.[script].sh | ./multirun.sh

name="ollama_bash_lib.sh"
file="../ollama-bash-lib/ollama_bash_lib.sh"

echo "Act as an expert Software Engineer."
echo "Do a critical code review of this $name script:"
echo
cat "$file"

