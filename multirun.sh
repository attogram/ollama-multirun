#!/bin/bash
# ollama multirun
# This script runs a prompt against all available models in Ollama and saves the results in HTML format.
# Requires: ollama, bash, expect, awk, sed, tr, wc
# Usage:
#  - Enter prompt manually: ./multirun.sh
#  - Enter prompt from pipe: echo "your prompt" | ./multirun.sh
#  - Enter prompt from a file: ./multirun.sh < prompt.txt

NAME="ollama-multirun"
VERSION="1.0"
URL="https://github.com/attogram/ollama-multirun"

echo; echo "$NAME v$VERSION"; echo

models=$(ollama list | awk '{if (NR > 1) print $1}' | sort) # Get list of models, sorted alphabetically
echo "Models:"; echo "$models"; echo
if [ -z "$models" ]; then
  echo "No models found. Please install models with 'ollama pull <model-name>'"
  exit 1
fi

function setPrompt {
  if [ -t 0 ]; then
    echo "Enter prompt:";
    read prompt
  else
    prompt=$(cat)  # get piped input
  fi
}

function textarea() {
  local content="$1" # Get the input
  if [ -z "$content" ]; then
    content=""
  fi
  local padding="$2"
  if [ -z "$padding" ]; then
    padding=0
  fi
  local lines=$(echo "$content\n" | wc -l) # Get number of lines in content
  lines=$((lines + padding))
  if [ "$lines" -gt 25 ]; then
    lines=25
  fi
  echo "<textarea readonly rows='$lines'>${content}</textarea>"
}

function safeTag() {
    local input="$1" # Get the input
    input=${input:0:50} # Truncate to first 50 characters
    input=$(echo "$input" | tr '[:upper:]' '[:lower:]') # Convert to lowercase
    input=$(echo "$input" | sed "s/ /_/g") # Replace spaces with underscores
    input=$(echo "$input" | sed 's/[^a-zA-Z0-9_\-]/_/g' | tr -cd 'a-zA-Z0-9_-')
    echo "$input" # Output the sanitized string
}

function clear_model {
  COMMAND="ollama run $1"
  echo "Clearing: $COMMAND"
  expect -c "spawn $COMMAND; 
    sleep 1;
    send -- \"/clear\n\"; 
    sleep 1;
    send -- \"/bye\n\"; 
    interact;"
  echo "Stopping: $1"
  ollama stop "$1"
}

function setHeaderAndFooter {
  HEADER=$(cat <<EOF
<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  body {
    margin: 5px;
    font-family: monospace;
  }
  textarea {
    width: 90%;
    white-space: pre-wrap;
  }
  header {
    background-color: #f0f0f0;
    border-bottom: 1px solid #ccc;
  }
</style>
EOF
  )

  FOOTER=$(cat <<EOF
<footer><p>Generated with <a target='$URL' href='$URL'>$NAME</a> v$VERSION</p></footer>
</body></html>
EOF
  )
}

setPrompt
echo; echo "Prompt:"; echo "$prompt"

tag=$(safeTag "$prompt")
directory="results/$tag"
echo; echo "Saving to directory: $directory/"

mkdir -p "$directory"
echo "$prompt" > "$directory/prompt.txt"

setHeaderAndFooter

indexFile="$directory/index.html"

echo "$HEADER" > "$indexFile"
echo "<title>$NAME: $tag</title></head><body>" >> "$indexFile"
echo "<header><p><a href='../index.html'>$NAME</a>: <b>$tag</b></p></header>" >> "$indexFile"
echo "<p>Prompt: (<a href='./prompt.txt'>raw</a>)<br />" >> "$indexFile"
textarea "$prompt" 1 >> "$indexFile"
echo "</p><p>Models:</p><ul>" >> "$indexFile"

# Loop through each model and run it with the given prompt
for model in $models; do
    echo; echo "Running Model: $model"
    output="$directory/$model.txt"
    statsFile="$directory/$model.stats.txt"

    echo "Saving to: $output"
    ollama run --verbose "$model" -- "${prompt}" > "$output" 2> "$statsFile"

    clear_model "$model"

    htmlFile="$directory/$model.html"
    echo "Creating: $htmlFile"
    echo "$HEADER" > "$htmlFile"
    echo "<title>$NAME: $model</title></head><body>" >> "$htmlFile"
    echo "<header><p><a href='../index.html'>$NAME</a>: <a href='./index.html'>$tag</a>: <b>$model</b></p></header>" >> "$htmlFile"

    echo "<p>Prompt: (<a href='./prompt.txt'>raw</a>)<br />" >> "$htmlFile"
    textarea "$prompt" 1 >> "$htmlFile"
    echo "</p>" >> "$htmlFile"

    echo "<p>Output: $model (<a href='./$model.txt'>raw</a>)<br />" >> "$htmlFile"
    textarea "$(cat "$output")" 5 >> "$htmlFile"
    echo "</p>" >> "$htmlFile"

    echo "<p>Stats: $model (<a href='./$model.stats.txt'>raw</a>)<br />" >> "$htmlFile"
    stats="$(cat "$statsFile")" # get content of stats file
    stats="total${stats#*total}" # remove everything before the first occurrence of word 'total'
    stats=${stats%%"$(tail -n1 <<<"$stats")"} # remove the last line
    echo "$stats" > "$statsFile" # save cleaned stats
    textarea "$stats" 0 >> "$htmlFile"
    echo "</p>" >> "$htmlFile"
 
    echo "$FOOTER" >> "$htmlFile"

    echo "<li><a href='./$model.html'>$model</a></li>" >> "$indexFile"
done

echo "</ul></body></html>" >> "$indexFile"
echo "$FOOTER" >> "$indexFile"

echo; echo "Done. Output saved in directory: $directory"

# Results index
resultsIndexFile="results/index.html"
echo "Creating: $resultsIndexFile"

echo "$HEADER" > $resultsIndexFile
echo "<title>$NAME: results</title></html><body>" >> $resultsIndexFile
echo "<header><p><b>$NAME</b>: results:</p></header>" >> $resultsIndexFile
echo "<ul>" >> $resultsIndexFile
for dir in results/*; do
    if [ -d "$dir" ]; then 
         echo "<li><a href='${dir##*/}/index.html'>${dir##*/}</a></li>" >> $resultsIndexFile
    fi
done
echo "</ul>" >> $resultsIndexFile
echo "$FOOTER" >> $resultsIndexFile
