#!/bin/bash
#
# ollama multirun
#
# Run a prompt against all models in ollama, save the modelFile as web pages
#
# Requires: ollama, bash, expect, awk, sed, tr, wc
#
# Usage:
#  - Enter prompt manually:    ./multirun.sh
#  - Enter prompt from a file: ./multirun.sh < prompt.txt
#  - Enter prompt from pipe:   echo "your prompt" | ./multirun.sh
#  - Enter prompt with text and file:  echo "explain this file: $(cat filename)" | ./multirun.sh

NAME="ollama-multirun"
VERSION="1.4"
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
  content=$(echo "$content" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g') # Escape HTML special characters
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
  echo "Clearing: $1"
  local run="ollama run $1"
  expect -c "spawn $run
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
    font-family: monospace;
    margin: 5px;
  }
  textarea {
    white-space: pre-wrap;
    width: 90%;
  }
  header, footer {
    background-color: #f0f0f0;
    margin: 5px;
    padding: 5px;
  }
  .menu {
    font-size: small;
  }
</style>
EOF
  )

  FOOTER=$(cat <<EOF
<footer><p>Generated with <a target='$NAME' href='$URL'>$NAME</a> v$VERSION</p></footer>
</body></html>
EOF
  )
}

function createMenu {
  local currentModel="$1"
  echo "<span class='menu'>Models: "
  for modelName in $models; do
    if [ "$modelName" == "$currentModel" ]; then
      echo "<b>$modelName</b>, "
    else
      echo "<a href='./$modelName.html'>$modelName</a>, "
    fi
  done
  echo '</span>';
}

function createResultsIndexFile {
  resultsIndexFile="results/index.html"
  echo "Creating: $resultsIndexFile"
  {
    echo "$HEADER<title>$NAME: results</title></head><body>"
    echo "<header><p><b>$NAME</b>: results:</p></header>"
    echo "<ul>"

    for dir in results/*; do
      if [ -d "$dir" ]; then
        echo "<li><a href='${dir##*/}/index.html'>${dir##*/}</a></li>"
      fi
    done

    echo "</ul>"
    echo "<p>Created on $(date '+%Y-%m-%d %H:%M:%S')</p>"
    echo "$FOOTER"
  } > $resultsIndexFile
}

function createHtmlFile {
      htmlFile="$directory/$model.html"
      echo "Creating: $htmlFile"
      {
        echo "$HEADER<title>$NAME: $model</title></head><body>"
        echo "<header><a href='../index.html'>$NAME</a>: <a href='./index.html'>$tag</a>: <b>$model</b><br /><br />"
        createMenu "$model"
        echo "</header>"

        echo "<p>Prompt: (<a href='./prompt.txt'>raw</a>)<br />"
        textarea "$prompt" 1
        echo "</p>"

        echo "<p>Output: $model (<a href='./$model.txt'>raw</a>)<br />"
        textarea "$(cat "$modelFile")" 5
        echo "</p>"

        echo "<p>Stats: $model (<a href='./$model.stats.txt'>raw</a>)<br />"
        stats="$(cat "$statsFile")" # get content of stats file
        stats="total${stats#*total}" # remove everything before the first occurrence of word 'total'
        stats=${stats%%"$(tail -n1 <<<"$stats")"} # remove the last line
        echo "$stats" > "$statsFile" # save cleaned stats
        textarea "$stats" 0
        echo "</p>"
        echo "<p>ollama Model Info: <a target='ollama' href='https://ollama.com/library/${model}'>$model</a></p>"
        echo "<p>Created on $(date '+%Y-%m-%d %H:%M:%S')</p>"
        echo "$FOOTER"
      } > "$htmlFile"
}

setPrompt
echo; echo "Prompt:"; echo "$prompt"

tag=$(safeTag "$prompt")
directory="results/${tag}_$(date '+%Y-%m-%d-%H-%M-%S')"
echo; echo "Creating: $directory/"
mkdir -p "$directory"

echo "Creating: $directory/prompt.txt"
echo "$prompt" > "$directory/prompt.txt"

setHeaderAndFooter

createResultsIndexFile

indexFile="$directory/index.html"
echo "Creating: $indexFile"
{
  echo "$HEADER<title>$NAME: $tag</title></head><body>"
  echo "<header><a href='../index.html'>$NAME</a>: <b>$tag</b><br /><br />"
  createMenu "index"
  echo  "</header>"
  echo "<p>Prompt: (<a href='./prompt.txt'>raw</a>)<br />"
  textarea "$prompt" 1
  echo "</p><p>Model Outputs:</p><ul>"
} > "$indexFile"

# Loop through each model and run it with the given prompt
for model in $models; do
    echo; echo "Running Model: $model"
    modelFile="$directory/$model.txt"
    statsFile="$directory/$model.stats.txt"
    echo "Creating: $modelFile"
    echo "Creating: $statsFile"
    ollama run --verbose "$model" -- "${prompt}" > "$modelFile" 2> "$statsFile"
    clear_model "$model"
    createHtmlFile
    echo "<li><a href='./$model.html'>$model</a></li>" >> "$indexFile"
done

# Finish the index file
{
  echo "</ul>"
  echo "Created on $(date '+%Y-%m-%d %H:%M:%S')</p>"
  echo "$FOOTER"
} >> "$indexFile"

echo; echo "Completed all Model runs: $directory/"
