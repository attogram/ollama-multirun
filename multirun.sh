#!/bin/bash
#
# ollama-multirun
#
# Bash shell script to run a prompt against all models in ollama, and save the output as web pages
#
# Usage:
#  - Enter prompt manually:    ./multirun.sh
#  - Enter prompt as argument: ./multirun.sh "your prompt"
#  - Enter prompt from file:   ./multirun.sh < prompt.txt
#  - Enter prompt from pipe:   echo "your prompt" | ./multirun.sh
#                              echo "summarize this file: $(cat filename)" | ./multirun.sh
#
#  - By default, will use all available models
#    To set a list of models to use, set as a comma-seperated list with -m
#      example:  ./multirun.sh -m deepseek-r1:1.5b,deepseek-r1:8b
#
# Requires: ollama, bash, expect, awk, basename, date, grep, mkdir, sed, sort, top, tr, uname, wc

NAME="ollama-multirun"
VERSION="4.0"
URL="https://github.com/attogram/ollama-multirun"
RESULTS_DIRECTORY="results"

echo; echo "$NAME v$VERSION"; echo

function parseCommandLine {
  modelsList=""
  prompt=""
  while (( "$#" )); do
    case "$1" in
      -m)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
          modelsList=$2
          shift 2
        else
          echo "Error: Argument for $1 is missing" >&2
          break
        fi
        ;;
      -*|--*=) # unsupported flags
        shift 2
        ;;
      *) # preserve positional arguments
        prompt="$prompt $1"
        shift
        ;;
    esac
  done
  # set positional arguments in their proper place
  eval set -- "$prompt"
}

function setModels {
  models=($(ollama list | awk '{if (NR > 1) print $1}' | sort)) # Get list of models, sorted alphabetically
  if [ -z "$models" ]; then
    echo "No models found. Please install models with 'ollama pull <model-name>'"
    exit 1
  fi

  parsedModels=()
  if [ -n "$modelsList" ]; then
    IFS=',' read -ra modelsListArray <<< "$modelsList" # parse csv into modelsListArray
    for m in "${modelsListArray[@]}"; do
      if [[ "${models[*]}" =~ "$m" ]]; then # if model exists
        parsedModels+=("$m")
      else
        echo "Error: model not found: $m"
        exit
      fi
    done
  fi
  if [ -n "$parsedModels" ]; then
    models=("${parsedModels[@]}")
  fi

  echo "models:";
  echo "${models[@]}"
  echo
}

function safeTag() {
  local input="$1" # Get the input
  input=${input:0:50} # Truncate to first 50 characters
  input=$(echo "$input" | tr '[:upper:]' '[:lower:]') # Convert to lowercase
  input=$(echo "$input" | sed "s/ /_/g") # Replace spaces with underscores
  input=$(echo "$input" | sed 's/[^a-zA-Z0-9_]/_/g' | tr -cd 'a-zA-Z0-9_')
  echo "$input" # Output the sanitized string
}

function createResultsDirectory {
  tag=$(safeTag "$prompt")
  tagDatetime=$(date '+%Y%m%d-%H%M%S')
  directory="${RESULTS_DIRECTORY}/${tag}_${tagDatetime}"
  echo; echo "Creating: $directory/"
  mkdir -p "$directory"
}

function setPrompt {
  if [ -n "$prompt" ]; then # if prompt is already set from command line
    return
  fi

  if [ -t 0 ]; then # Check if input is from a terminal (interactive)
    echo "Enter prompt:";
    read -r prompt # Read prompt from user input
    return
  fi

  prompt=$(cat) # Read from standard input (pipe or file)
}

function savePrompt {
  echo; echo "Prompt:"; echo "$prompt"; echo
  promptFile="$directory/prompt.txt"
  echo "Creating: $promptFile"
  echo "$prompt" > "$promptFile"

  # Github Prompt YAML: https://docs.github.com/en/github-models/use-github-models/storing-prompts-in-github-repositories
  echo "Creating: $directory/prompt.yaml"
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
  ) > "$directory/prompt.yaml"
}

function showPrompt {
  echo "<p>Prompt: (<a href='./prompt.txt'>raw</a>) (<a href='./${tag}.prompt.yaml'>yaml</a>)"
  echo "  words:$promptWords  bytes:$promptBytes<br />"
  textarea "$prompt" 0 10 # 0 padding, max 10 lines
  echo "</p>"
}

function showImages {
  if [ -n "$addedImages" ]; then
    for image in ${addedImages}; do
      echo -n "<div class='box'>"
      echo -n "<a target='image' href='$(basename $image)'><img src='$(basename $image)' alt='$image' width='250' /></a>"
      echo -n "</div>"
    done
    echo -n "<br />"
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

function clearModel {
  echo "Clearing: $1"
  local expectedPrompt=">>> "
  local run="ollama run $1"
  expect \
    -c "spawn $run" \
    -c "expect \"$expectedPrompt\"" \
    -c 'send -- "/clear\n"' \
    -c "expect \"$expectedPrompt\"" \
    -c 'send -- "/bye\n"' \
  ;
  echo "Stopping: $1"
  ollama stop "$1"
}

function showHeader {
  title="$1"
  cat << "EOF"
  <!DOCTYPE html>
  <html lang="en">
  <head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    a:hover { background-color: yellow; color: black; }
    body { font-family: monospace; }
    header, footer { background-color: #f0f0f0; padding: 10px; }
    li { margin: 5px; }
    table, td, th { border-collapse: collapse; }
    td, th { border: 1px solid #cccccc; padding: 5px; text-align: right; }
    tr:hover { background-color: lightyellow; color: black; }
    textarea { border: 1px solid #cccccc; white-space: pre-wrap; width: 90%; }
    .box { display: inline-block; margin: 3px; padding: 2px; vertical-align: top; }
    .left { text-align: left; }
    .menu { font-size: small; }
  </style>
EOF
  echo "<title>$title</title></head><body>"
}

function showFooter {
  echo "<br /><br />"
  echo "<footer>"
  echo "<p>page created:   $(date '+%Y-%m-%d %H:%M:%S')</p>"
  echo "<p>Generated with: <a target='$NAME' href='$URL'>$NAME</a> v$VERSION</p>"
  echo "</footer></body></html>"
}

function createMenu {
  local currentModel="$1"
  echo "<span class='menu'>"
  echo "<a href='models.html'>models</a>: "
  for modelName in ${models[@]}; do
    if [ "$modelName" == "$currentModel" ]; then
      echo "<b>$modelName</b> "
    else
      echo "<a href='./$modelName.html'>$modelName</a> "
    fi
  done
  echo '</span>';
}

function setStats {
  statsTotalDuration=$(grep -oE "total duration:[[:space:]]+(.*)" "$statsFile" | awk '{ print $NF }')
  statsLoadDuration=$(grep -oE "load duration:[[:space:]]+(.*)" "$statsFile" | awk '{ print $NF }')
  statsPromptEvalCount=$(grep -oE "prompt eval count:[[:space:]]+(.*)" "$statsFile" | awk '{ print $4, $5 }')
  statsPromptEvalDuration=$(grep -oE "prompt eval duration:[[:space:]]+(.*)" "$statsFile" | awk '{ print $NF }')
  statsPromptEvalRate=$(grep -oE "prompt eval rate:[[:space:]]+(.*)" "$statsFile" | awk '{ print $4, $5 }')
  statsEvalCount=$(grep -oE "^eval count:[[:space:]]+(.*)" "$statsFile" | awk '{ print $3, $4 }')
  statsEvalDuration=$(grep -oE "^eval duration:[[:space:]]+(.*)" "$statsFile" | awk '{ print $NF }')
  statsEvalRate=$(grep -oE "^eval rate:[[:space:]]+(.*)" "$statsFile" | awk '{ print $3, $4 }')

  addedImages=$(grep -oE "Added image '(.*)'" "$statsFile" | awk '{ print $NF }' | sed "s/'//g")
  if [ -n "$addedImages" ]; then
    for image in ${addedImages}; do
      if ! [ -f "$directory"/"$(basename $image)" ]; then
        echo "Copying image: $image"
        cp $image $directory
      fi
    done
  fi

  responseWords=$(wc -w < "$modelFile" | awk '{print $1}')
  responseBytes=$(wc -c < "$modelFile" | awk '{print $1}')

  promptWords=$(wc -w < "$promptFile" | awk '{print $1}')
  promptBytes=$(wc -c < "$promptFile" | awk '{print $1}')
}

function setOllamaStats {
  ollamaVersion=$(ollama -v | awk '{print $4}')
  ollamaPs=$(ollama ps | awk '{print $1, $2, $3, $4, $5, $6}' | sed '1d') # Get the first 6 columns of ollama ps output, skipping the header
  ollamaModel=$(echo "$ollamaPs" | awk '{print $1}') # Get the model name
  ollamaProcessor=$(echo "$ollamaPs" | awk '{print $5, $6}') # Get the processor
  ollamaSize=$(echo "$ollamaPs" | awk '{print $3, $4}') # Get the model size
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

function saveModelInfo { # Create model info files - for each model, do 'ollama show' and save the results to text file
  for model in "${models[@]}"; do
    modelInfoFileFile="$directory/$model.info.txt"
    echo "Creating: $modelInfoFileFile"
    ollama show "$model" > "$modelInfoFileFile"
  done
}

function setModelInfo {
  modelInfoFile="$directory/$model.info.txt"
  modelCapabilities=()
  modelSystemPrompt=""
  modelTemperature=""
  section=""

  while IFS= read -r line; do # Read the content of the file line by line
    line="$(echo -e "${line}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')" # Trim leading/trailing whitespace
    if [[ -z "$line" ]]; then
      section=""
      continue; # Skip empty lines
    fi
    if [[ $line == "Model"* ]]; then
      section="Model"
      continue
    elif [[ $line == "Capabilities"* ]]; then
      section="Capabilities"
      continue
    elif [[ $line == "System"* ]]; then
      section="System"
      continue
    elif [[ $line == "Parameters"* ]]; then
      section="Parameters"
      continue
    elif [[ $line == "License"* ]]; then
      section="License"
      continue
    elif [[ $line == "Projector"* ]]; then
      section="Projector"
      continue
    fi

    case $section in
      "Model")
        if [[ "$line" == "architecture"* ]]; then
          modelArchitecture=$(echo "$line" | awk '/architecture/ {print $2}') # Get model architecture
        fi
        if [[ "$line" == "parameters"* ]]; then
          modelParameters=$(echo "$line" | awk '/parameters/ {print $2}') # Get model parameters
        fi
        if [[ "$line" == "context length"* ]]; then
          modelContextLength=$(echo "$line" | awk '/context length/ {print $3}') # Get model context length
        fi
        if [[ "$line" == "embedding length"* ]]; then
          modelEmbeddingLength=$(echo "$line" | awk '/embedding length/ {print $3}') # Get model embedding length
        fi
        if [[ "$line" == "quantization"* ]]; then
          modelQuantization=$(echo "$line" | awk '/quantization/ {print $2}') # Get model quantization
        fi
        ;;
      "Capabilities")
        modelCapabilities+=("$line")
        ;;
      "System")
        modelSystemPrompt+="$line"$'\n'
        ;;
      "Parameters")
        if [[ "$line" == "temperature"* ]]; then
          modelTemperature=$(echo "$line" | awk '/temperature/ {print $2}') # Get model temperature
        fi
        ;;
    esac
  done < "$modelInfoFile"
}

function createModelsIndexFile {
  modelsIndexFile="$directory/models.html"
  echo "Creating: $modelsIndexFile"
  {
    showHeader "$NAME: models"
    echo "<header><a href='../index.html'>$NAME</a>: <a href='./index.html'>$tag</a>: <b>models</b>: $tagDatetime</header>"
    cat <<- "EOF"
<br />
<table>
  <tr>
    <th class='left'>model</th>
    <th>architecture</th>
    <th>parameters</th>
    <th>context<br />length</th>
    <th>embedding<br />length</th>
    <th>quantization</th>
    <th>temperature</th>
    <th>capabilities</th>
    <th class='left'>system prompt</th>
    <th>(raw)</th>
  </tr>
EOF
  } > "$modelsIndexFile"

  for model in "${models[@]}"; do
    setModelInfo
    {
      echo "<tr>"
      echo "<td class='left'><a href='./$model.html'>$model</a></td>"
      echo "<td>$modelArchitecture</td>"
      echo "<td>$modelParameters</td>"
      echo "<td>$modelContextLength</td>"
      echo "<td>$modelEmbeddingLength</td>"
      echo "<td>$modelQuantization</td>"
      echo "<td>$modelTemperature</td>"
      echo "<td class='left'>$(printf "%s<br />" "${modelCapabilities[@]}")</td>"
      echo "<td class='left'>$modelSystemPrompt</td>"
      echo "<td><a href='./$model.info.txt'>raw</a></td>"
      echo "</tr>"
    } >> "$modelsIndexFile"
  done

  {
    echo "</table>"
    showFooter
  } >> "$modelsIndexFile"
}

function createModelFile {
  modelHtmlFile="$directory/$model.html"
  echo "Creating: $modelHtmlFile"
  {
    showHeader "$NAME: $model"
    echo "<header><a href='../index.html'>$NAME</a>: <a href='./index.html'>$tag</a>: <b>$model</b>: $tagDatetime<br /><br />"
    createMenu "$model"
    echo "</header>"
    showPrompt
    showImages
    echo "<p>Output: $model (<a href='./$model.txt'>raw</a>)<br />"
    textarea "$(cat "$modelFile")" 3 25 # 5 padding, max 30 lines
    echo "</p>"

    echo "<div class='box'><table>"
    echo "<tr><td class='left' colspan='2'>Stats (<a href='./$model.stats.txt'>raw</a>)</td></tr>"
    echo "<tr><td class='left'>words</td><td>$responseWords</td></tr>"
    echo "<tr><td class='left'>bytes</td><td>$responseBytes</td></tr>"
    echo "<tr><td class='left'>total duration</td><td>$statsTotalDuration</td></tr>"
    echo "<tr><td class='left'>load duration</td><td>$statsLoadDuration</td></tr>"
    echo "<tr><td class='left'>prompt eval count</td><td>$statsPromptEvalCount</td></tr>"
    echo "<tr><td class='left'>prompt eval duration</td><td>$statsPromptEvalDuration</td></tr>"
    echo "<tr><td class='left'>prompt eval rate</td><td>$statsPromptEvalRate</td></tr>"
    echo "<tr><td class='left'>eval count</td><td>$statsEvalCount</td></tr>"
    echo "<tr><td class='left'>eval duration</td><td>$statsEvalDuration</td></tr>"
    echo "<tr><td class='left'>eval rate</td><td>$statsEvalRate</td></tr>"
    echo "</table></div>"

    echo "<div class='box'><table>"
    echo "<tr><td class='left' colspan='2'>Model (<a href='./$model.info.txt'>raw</a>)</td></tr>"
    echo "<tr><td class='left'>name</td><td class='left'><a target='ollama' href='https://ollama.com/library/${model}'>$model</a></td></tr>"
    echo "<tr><td class='left'>architecture</td><td class='left'>$modelArchitecture</td></tr>"
    echo "<tr><td class='left'>size</td><td class='left'>$ollamaSize</td></tr>"
    echo "<tr><td class='left'>parameters</td><td class='left'>$modelParameters</td></tr>"
    echo "<tr><td class='left'>context length</td><td class='left'>$modelContextLength</td></tr>"
    echo "<tr><td class='left'>embedding length</td><td  class='left'>$modelEmbeddingLength</td></tr>"
    echo "<tr><td class='left'>quantization</td><td class='left'>$modelQuantization</td></tr>"
    echo "<tr><td class='left'>capabilities</td><td class='left'>$(printf "%s<br />" "${modelCapabilities[@]}")</td>"
    echo "</table></div>"

    echo "<div class='box'><table>"
    echo "<tr><td class='left' colspan='2'>System</td></tr>"
    echo "<tr><td class='left'>ollama proc</td><td class='left'>$ollamaProcessor</td></tr>"
    echo "<tr><td class='left'>ollama version</td><td class='left'>$ollamaVersion</td></tr>"
    echo "<tr><td class='left'>sys arch</td><td class='left'>$systemArch</td></tr>"
    echo "<tr><td class='left'>sys processor</td><td class='left'>$systemProcessor</td></tr>"
    echo "<tr><td class='left'>sys memory</td><td class='left'>$systemMemoryUsed + $systemMemoryAvail</td></tr>"
    echo "<tr><td class='left'>sys OS</td><td class='left'>$systemOSName $systemOSVersion</td></tr>"
    echo "</table></div>"

    showFooter
  } > "$modelHtmlFile"
}

function createResultsIndexFile {
  resultsIndexFile="${RESULTS_DIRECTORY}/index.html"
  echo "Creating: $resultsIndexFile"
  {
    showHeader "$NAME: results"
    echo "<header><p><b>$NAME</b></p></header>"
    echo "<ul>"
    for dir in "$RESULTS_DIRECTORY"/*; do
      if [ -d "$dir" ]; then
        echo "<li><a href='${dir##*/}/index.html'>${dir##*/}</a></li>"
      fi
    done
    echo "</ul>"
    showFooter
  } > $resultsIndexFile
}

function createIndexFile {
  indexFile="$directory/index.html"
  echo "Creating: $indexFile"
  {
    showHeader "$NAME: $tag"
    echo "<header><a href='../index.html'>$NAME</a>: <b>$tag</b>: $tagDatetime<br /><br />"
    createMenu "index"
    echo  "</header>"
    showPrompt
    echo "<!-- IMAGES -->"
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
  (
    echo "<tr>"
    echo "<td class='left'><a href='./$model.html'>$model</a></td>"
    echo "<td>$responseWords</td>"
    echo "<td>$responseBytes</td>"
    echo "<td>$statsTotalDuration</td>"
    echo "<td>$statsLoadDuration</td>"
    echo "<td>$statsPromptEvalCount</td>"
    echo "<td>$statsPromptEvalDuration</td>"
    echo "<td>$statsPromptEvalRate</td>"
    echo "<td>$statsEvalCount</td>"
    echo "<td>$statsEvalDuration</td>"
    echo "<td>$statsEvalRate</td>"
    echo "</tr>"
  ) >> "$indexFile"
}

function finishIndexFile {
  {
    echo "</table>"
    echo "<br /><br />"
    echo "<table>"
    echo "<tr><td class='left' colspan='2'>System</td></tr>"
    echo "<tr><td class='left'>ollama proc</td><td>$ollamaProcessor</td></tr>"
    echo "<tr><td class='left'>ollama version</td><td>$ollamaVersion</td></tr>"
    echo "<tr><td class='left'>sys arch</td><td>$systemArch</td></tr>"
    echo "<tr><td class='left'>sys processor</td><td>$systemProcessor</td></tr>"
    echo "<tr><td class='left'>sys memory</td><td>$systemMemoryUsed + $systemMemoryAvail</td></tr>"
    echo "<tr><td class='left'>sys OS</td><td>$systemOSName $systemOSVersion</td></tr>"
    echo "</table>"
    showFooter
  } >> "$indexFile"

  imagesHtml=$(showImages)
  sed -i -e "s#<!-- IMAGES -->#${imagesHtml}#" $indexFile
}

export OLLAMA_MAX_LOADED_MODELS=1
export OLLAMA_KEEP_ALIVE=0 # or: run --keepalive 0

parseCommandLine "$@"
setModels
setPrompt
createResultsDirectory
savePrompt
setSystemStats
createResultsIndexFile
createIndexFile
saveModelInfo
createModelsIndexFile

for model in "${models[@]}"; do # Loop through each model and run it with the given prompt
  echo; echo "Running model: $model"
  modelFile="$directory/$model.txt"
  statsFile="$directory/$model.stats.txt"
  echo "Creating: $modelFile"
  echo "Creating: $statsFile"
  ollama run --verbose "$model" -- "${prompt}" > "$modelFile" 2> "$statsFile"
  setModelInfo
  setOllamaStats
  setStats
  createModelFile
  addModelToIndexFile
  clearModel "$model"
done

finishIndexFile

echo; echo "Done: $directory/"
