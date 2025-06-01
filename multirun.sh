#!/bin/bash
#
# ollama multirun
#
# Bash shell script to run a prompt against all models in ollama, and save the output as web pages
#
# Usage:
#  - Enter prompt manually:  ./multirun.sh
#  - Enter prompt from file: ./multirun.sh < prompt.txt
#  - Enter prompt from pipe: echo "your prompt" | ./multirun.sh
#                            echo "summarize this file: $(cat filename)" | ./multirun.sh
#
# Requires: ollama, bash, expect, awk, sed, tr, uname, wc

NAME="ollama multirun"
VERSION="2.6"
URL="https://github.com/attogram/ollama-multirun"
RESULTS_DIRECTORY="results"

echo; echo "$NAME v$VERSION"; echo

function setModels {
  models=$(ollama list | awk '{if (NR > 1) print $1}' | sort) # Get list of models, sorted alphabetically
  echo "Models:"; echo "$models"; echo
  if [ -z "$models" ]; then
    echo "No models found. Please install models with 'ollama pull <model-name>'"
    exit 1
  fi
}

function createResultsDirectory {
  tag=$(safeTag "$prompt")
  directory="${RESULTS_DIRECTORY}/${tag}_$(date '+%Y%m%d-%H%M%S')"
  echo; echo "Creating: $directory/"
  mkdir -p "$directory"
}

function setPrompt {
  if [ -t 0 ]; then
    echo "Enter prompt:";
    read -r prompt
  else
    prompt=$(cat)  # get piped input
  fi
  echo; echo "Prompt:"; echo "$prompt"
}

function savePrompt {
  promptFile="$directory/prompt.txt"
  echo "Creating: $promptFile"
  echo "$prompt" > "$promptFile"

  # Github Prompt YAML: https://docs.github.com/en/github-models/use-github-models/storing-prompts-in-github-repositories
  echo "Creating: $directory/$tag.prompt.yaml"
  (
    echo "messages:"
    echo "  - role: system"
    echo "    content: ''"
    echo "  - role: user"
    echo "    content: |"
    while IFS= read -r line; do
      echo "      $line"
    done <<< "$prompt"
    echo "model: ''"
  ) > "$directory/$tag.prompt.yaml"
}

function showPrompt {
    promptWords=$(wc -w < "$promptFile" | awk '{print $1}')
    promptBytes=$(wc -c < "$promptFile" | awk '{print $1}')
    echo "<p>Prompt: (<a href='./prompt.txt'>raw</a>) (<a href='./${tag}.prompt.yaml'>yaml</a>)"
    echo "  words:$promptWords  bytes:$promptBytes<br />"
    textarea "$prompt" 0 10 # 0 padding, max 10 lines
    echo "</p>"
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
  local max="$3"
  if [ -z "$max" ]; then
    max=25
  fi
  local lines=$(echo "$content\n" | wc -l) # Get number of lines in content
  lines=$((lines + padding))
  if [ "$lines" -gt "$max" ]; then
    lines=$max
  fi
  content=$(echo "$content" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g') # Escape HTML special characters
  echo "<textarea readonly rows='$lines'>${content}</textarea>"
}

function safeTag() {
    local input="$1" # Get the input
    input=${input:0:50} # Truncate to first 50 characters
    input=$(echo "$input" | tr '[:upper:]' '[:lower:]') # Convert to lowercase
    input=$(echo "$input" | sed "s/ /_/g") # Replace spaces with underscores
    input=$(echo "$input" | sed 's/[^a-zA-Z0-9_]/_/g' | tr -cd 'a-zA-Z0-9_')
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
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  body { font-family: monospace; }
  textarea { border: 1px solid #cccccc; white-space: pre-wrap; width: 90%; }
  header, footer { background-color: #f0f0f0; padding: 10px; }
  .menu { font-size: small; }
  table, td, th { border-collapse: collapse; }
  td, th { border: 1px solid #cccccc; padding: 5px; text-align: right; }
  .left { text-align: left; }
  li { margin: 5px; }
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
  echo "<span class='menu'>models: "
  for modelName in $models; do
    if [ "$modelName" == "$currentModel" ]; then
      echo "<b>$modelName</b> "
    else
      echo "<a href='./$modelName.html'>$modelName</a> "
    fi
  done
  echo '</span>';
}

function createResultsIndexFile {
  resultsIndexFile="${RESULTS_DIRECTORY}/index.html"
  echo "Creating: $resultsIndexFile"
  {
    echo "$HEADER<title>$NAME: results</title></head><body>"
    echo "<header><p><b>$NAME</b></p></header>"
    echo "<ul>"
    for dir in "$RESULTS_DIRECTORY"/*; do
      if [ -d "$dir" ]; then
        echo "<li><a href='${dir##*/}/index.html'>${dir##*/}</a></li>"
      fi
    done
    echo "</ul>"
    echo "<br /><br /><p>page created: $(date '+%Y-%m-%d %H:%M:%S')</p>"
    echo "$FOOTER"
  } > $resultsIndexFile
}

function createIndexFile {
  indexFile="$directory/index.html"
  echo "Creating: $indexFile"
  {
    echo "$HEADER<title>$NAME: $tag</title></head><body>"
    echo "<header><a href='../index.html'>$NAME</a>: <b>$tag</b><br /><br />"
    createMenu "index"
    echo  "</header>"
    showPrompt
    cat <<- "EOF"
<table>
  <tr>
    <th class='left'>model</th>
    <th>words</th>
    <th>bytes</th>
    <th>total<br />duration</th>
    <th>load<br />duration</th>
    <th>prompt eval<br />count</th>
    <th>prompt eval<br />duration</th>
    <th>prompt eval<br />rate</th>
    <th>eval<br />count</th>
    <th>eval<br />duration</th>
    <th>eval<br />rate</th>
  </tr>
EOF
  } > "$indexFile"
}

function addModelToIndexFile {
    responseWords=$(wc -w < "$modelFile" | awk '{print $1}')
    responseBytes=$(wc -c < "$modelFile" | awk '{print $1}')
    (
        echo "<tr><td class='left'><a href='./$model.html'>$model</a></td><td >$responseWords</td><td>$responseBytes</td>"
        while read -r line; do
          value=$(echo "$line" | cut -d ':' -f2) # parse the stats file per line, splitting on : character, getting the second part as the value
          if [[ -n "$value" ]]; then
            echo "<td>${value}</td>";
          fi
        done < "$statsFile"
        echo "</tr>"
    ) >> "$indexFile"
}

function finishIndexFile {
  {
    echo "</table>"
    echo
    echo "<pre>"
    echo "ollama proc:    $ollamaProcessor"
    echo "ollama version: $ollamaVersion"
    echo "sys arch:       $systemArch"
    echo "sys processor:  $systemProcessor"
    echo "sys memory:     $systemMemoryUsed + $systemMemoryAvail"
    echo "sys OS:         $systemOSName $systemOSVersion"
    echo "page created:   $(date '+%Y-%m-%d %H:%M:%S')</pre>"
    echo "$FOOTER"
  } >> "$indexFile"
}

function createModelFile {
      modelHtmlFile="$directory/$model.html"
      echo "Creating: $modelHtmlFile"
      resultsWords=$(wc -w < "$modelFile" | awk '{print $1}')
      resultsBytes=$(wc -c < "$modelFile" | awk '{print $1}')
      {
        echo "$HEADER<title>$NAME: $model</title></head><body>"
        echo "<header><a href='../index.html'>$NAME</a>: <a href='./index.html'>$tag</a>: <b>$model</b><br /><br />"
        createMenu "$model"
        echo "</header>"
        showPrompt
        echo "<p>Output: $model (<a href='./$model.txt'>raw</a>)  words:$resultsWords  bytes:$resultsBytes<br />"
        textarea "$(cat "$modelFile")" 5 30 # 5 padding, max 30 lines
        echo "</p>"
        echo "<p>Stats: $model (<a href='./$model.stats.txt'>raw</a>)<br />"
        textarea "$stats" 0 10 # 0 padding, max 10 lines
        echo "</p>"
        echo "<pre>"
        echo "model name:     <a target='ollama' href='https://ollama.com/library/${ollamaModel}'>$ollamaModel</a>"
        echo "model size:     $ollamaSize"
        echo "model arch:     $modelArchitecture"
        echo "model params:   $modelParameters"
        echo "model context:  $modelContextLength"
        echo "model embed:    $modelEmbeddingLength"
        echo "model quant:    $modelQuantization"
        echo "ollama proc:    $ollamaProcessor"
        echo "ollama version: $ollamaVersion"
        echo "sys arch:       $systemArch"
        echo "sys processor:  $systemProcessor"
        echo "sys memory:     $systemMemoryUsed + $systemMemoryAvail"
        echo "sys OS:         $systemOSName $systemOSVersion"
        echo "page created:   $(date '+%Y-%m-%d %H:%M:%S')</pre>"
        echo "$FOOTER"
      } > "$modelHtmlFile"
}

function setStats {
    stats="$(cat "$statsFile")" # get content of stats file
    stats="total${stats#*total}" # remove everything before the first occurrence of word 'total'
    stats=${stats%%"$(tail -n1 <<<"$stats")"} # remove the last line
    echo "$stats" > "$statsFile" # save cleaned stats
}

function setOllamaStats {
  ollamaPs=$(ollama ps | awk '{print $1, $2, $3, $4, $5, $6}' | sed '1d') # Get the first 6 columns of ollama ps output, skipping the header
  ollamaModel=$(echo "$ollamaPs" | awk '{print $1}') # Get the model name
  ollamaSize=$(echo "$ollamaPs" | awk '{print $3, $4}') # Get the model size
  ollamaProcessor=$(echo "$ollamaPs" | awk '{print $5, $6}') # Get the processor
  ollamaVersion=$(ollama -v | awk '{print $4}')
}

function setSystemStats {
  systemArch=$(uname -m) # Get hardware platform
  systemProcessor=$(uname -p) # Get system processor
  systemOSName=$(uname -s) # Get system OS name
  systemOSVersion=$(uname -r) # Get system OS version
  top=$(top -l 1)
  systemMemoryUsed=$(echo "$top" | awk '/PhysMem/ {print $2}') # Get system memory used
  systemMemoryAvail=$(echo "$top" | awk '/PhysMem/ {print $6}') # Get system memory available
}

function setModelInfo {
  modelInfo=$(ollama show "$model")
  modelArchitecture=$(echo "$modelInfo" | awk '/architecture/ {print $2}') # Get model architecture
  modelParameters=$(echo "$modelInfo" | awk '/parameters/ {print $2}') # Get model parameters
  modelContextLength=$(echo "$modelInfo" | awk '/context length/ {print $3}') # Get model context length
  modelEmbeddingLength=$(echo "$modelInfo" | awk '/embedding length/ {print $3}') # Get model embedding length
  modelQuantization=$(echo "$modelInfo" | awk '/quantization/ {print $2}') # Get model quantization
}

setModels
setPrompt
createResultsDirectory
savePrompt
setSystemStats
setHeaderAndFooter
createResultsIndexFile
createIndexFile

# Loop through each model and run it with the given prompt
for model in $models; do
    echo; echo "Running model: $model"
    modelFile="$directory/$model.txt"
    statsFile="$directory/$model.stats.txt"
    echo "Creating: $modelFile"
    echo "Creating: $statsFile"
    ollama run --verbose "$model" -- "${prompt}" > "$modelFile" 2> "$statsFile"
    setModelInfo
    setOllamaStats
    setStats
    clear_model "$model"
    createModelFile
    addModelToIndexFile
done

finishIndexFile

echo; echo "Done: $directory/"
