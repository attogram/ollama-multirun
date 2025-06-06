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
# Requires: ollama, bash, expect, awk, basename, grep, sed, top, tr, uname, wc

NAME="ollama-multirun"
VERSION="3.4"
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

  models=$(ollama list | awk '{if (NR > 1) print $1}' | sort) # Get list of models, sorted alphabetically

  if [ -z "$models" ]; then
    echo "No models found. Please install models with 'ollama pull <model-name>'"
    exit 1
  fi

  newModels=()

  if [ -n "$modelsList" ]; then
    IFS=',' read -ra modelsListArray <<< "$modelsList" # parse csv into modelsListArray
    for m in "${modelsListArray[@]}"; do
      if [[ "${models[*]}" =~ "$m" ]]; then # if model exists
        newModels+=("$m")
      else
        echo "Error: model not found: $m"
        exit
      fi
    done
  fi

  if [ -n "$newModels" ]; then
    models=("${newModels[@]}")
  fi

  echo "Models:";
  for m in "${models[@]}"; do
    echo "$m"
  done
  echo
}

function createResultsDirectory {
  tag=$(safeTag "$prompt")
  tagDatetime=$(date '+%Y%m%d-%H%M%S')
  directory="${RESULTS_DIRECTORY}/${tag}_${tagDatetime}"
  echo; echo "Creating: $directory/"
  mkdir -p "$directory"
}

function setPrompt {

  # if prompt is already set from command line
  if [ -n "$prompt" ]; then
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
  )

  FOOTER=$(cat <<EOF
<footer><p>Generated with <a target='$NAME' href='$URL'>$NAME</a> v$VERSION</p></footer>
</body></html>
EOF
  )
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
    echo "<br /><br />page created:   $(date '+%Y-%m-%d %H:%M:%S')"
    echo "$FOOTER"
  } >> "$indexFile"

    imagesHtml=$(showImages)
    sed -i -e "s#<!-- IMAGES -->#${imagesHtml}#" $indexFile
}

function createModelFile {
  modelHtmlFile="$directory/$model.html"
  echo "Creating: $modelHtmlFile"
  {
    echo "$HEADER<title>$NAME: $model</title></head><body>"
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
    echo "<tr><td class='left' colspan='2'>Model</td></tr>"
    echo "<tr><td class='left'>name</td><td><a target='ollama' href='https://ollama.com/library/${ollamaModel}'>$ollamaModel</a></td></tr>"
    echo "<tr><td class='left'>architecture</td><td>$modelArchitecture</td></tr>"
    echo "<tr><td class='left'>size</td><td>$ollamaSize</td></tr>"
    echo "<tr><td class='left'>parameters</td><td>$modelParameters</td></tr>"
    echo "<tr><td class='left'>context length</td><td>$modelContextLength</td></tr>"
    echo "<tr><td class='left'>embedding length</td><td>$modelEmbeddingLength</td></tr>"
    echo "<tr><td class='left'>quantization</td><td>$modelQuantization</td></tr>"
    echo "</table></div>"

    echo "<div class='box'><table>"
    echo "<tr><td class='left' colspan='2'>System</td></tr>"
    echo "<tr><td class='left'>ollama proc</td><td>$ollamaProcessor</td></tr>"
    echo "<tr><td class='left'>ollama version</td><td>$ollamaVersion</td></tr>"
    echo "<tr><td class='left'>sys arch</td><td>$systemArch</td></tr>"
    echo "<tr><td class='left'>sys processor</td><td>$systemProcessor</td></tr>"
    echo "<tr><td class='left'>sys memory</td><td>$systemMemoryUsed + $systemMemoryAvail</td></tr>"
    echo "<tr><td class='left'>sys OS</td><td>$systemOSName $systemOSVersion</td></tr>"
    echo "</table></div>"

    echo "<br /><br />page created:   $(date '+%Y-%m-%d %H:%M:%S')"
    echo "$FOOTER"
  } > "$modelHtmlFile"
}

function createModelsIndexFile {
  modelsIndexFile="$directory/models.html"
  echo "Creating: $modelsIndexFile"
  {
    echo "$HEADER<title>$NAME: models</title></head><body>"
    echo "<header><a href='../index.html'>$NAME</a>: <a href='./index.html'>$tag</a>: <b>models</b>: $tagDatetime</header>"
    cat <<- "EOF"
<br />
<table>
  <tr>
    <th class='left'>model</th>
    <th>architecture</th>
    <th>size</th>
    <th>parameters</th>
    <th>context<br />length</th>
    <th>embedding<br />length</th>
    <th>quantization</th>
  </tr>
EOF
  } > "$modelsIndexFile"
}

function addModelToModelsIndexFile {
  {
    echo "<tr>"
    echo "<td class='left'><a href='./$model.html'>$model</a></td>"
    echo "<td>$modelArchitecture</td>"
    echo "<td>$ollamaSize</td>"
    echo "<td>$modelParameters</td>"
    echo "<td>$modelContextLength</td>"
    echo "<td>$modelEmbeddingLength</td>"
    echo "<td>$modelQuantization</td>"
    echo "</tr>"
  } >> "$modelsIndexFile"
}

function finishModelsIndexFile {
  {
    echo "</table>"
    echo "<br /><br /><p>page created: $(date '+%Y-%m-%d %H:%M:%S')</p>"
    echo "$FOOTER"
  } >> "$modelsIndexFile"
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

parseCommandLine "$@"
setModels
setPrompt
createResultsDirectory
savePrompt
setSystemStats
setHeaderAndFooter
createResultsIndexFile
createIndexFile
createModelsIndexFile

# Loop through each model and run it with the given prompt
for model in "${models[@]}"; do
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
    addModelToModelsIndexFile
done

finishModelsIndexFile
finishIndexFile

echo; echo "Done: $directory/"
