#!/usr/bin/env bash
#
# Ollama Multirun
#
# Bash shell script to run a prompt against all models in Ollama, and save the output as web pages
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
#  - By default, will use "./results" as the results output directory
#    To set a results output directory:
#      ./multirun.sh -r ./path/to/directory
#
#  - By default, will wait 5 minutes for models to respond.
#    To set new timeout (in seconds):
#      ./multirun.sh -t 30

OLLAMA_MULTIRUN_NAME="ollama-multirun"
OLLAMA_MULTIRUN_VERSION="5.21.0"
OLLAMA_MULTIRUN_URL="https://github.com/attogram/ollama-multirun"
OLLAMA_MULTIRUN_DISCORD="https://discord.gg/BGQJCbYVBa"
OLLAMA_MULTIRUN_LICENSE="MIT"
OLLAMA_MULTIRUN_COPYRIGHT="Copyright (c) 2025 Ollama Bash Lib, Attogram Project <https://github.com/attogram>"

TIMEOUT="300" # number of seconds to allow model to respond

usage() {
  me=$(basename "$0")
  echo "$OLLAMA_MULTIRUN_NAME"; echo
  echo "Usage:"
  echo "  ./$me [flags]"
  echo "  ./$me [flags] [prompt]"
  echo; echo "Flags:";
  echo "  -h       -- Help for $OLLAMA_MULTIRUN_NAME"
  echo "  -m model1,model2  -- Use specific models (comma separated list)"
  echo "  -r <dir> -- Set results directory"
  echo "  -t #     -- Set timeout, in seconds"
  echo "  -v       -- Show version information"
  echo "  [prompt] -- Set the prompt (\"Example prompt\")"
}

parseCommandLine() {
  modelsList=""
  resultsDirectory="results"
  prompt=""
  while (( "$#" )); do
    case "$1" in
      -h)
        usage
        exit 0
        ;;
      -m) # specify models to run
        if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
          modelsList=$2
          shift 2
        else
          echo "Error: Argument for $1 is missing" >&2
          exit 1
        fi
        ;;
      -r) # specify results outputDirectory
        if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
          resultsDirectory=$2
          shift 2
        else
          echo "Error: Argument for $1 is missing" >&2
          exit 1
        fi
        ;;
      -t) # specify timeout in seconds
        if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
          TIMEOUT=$2
          shift 2
        else
          echo "Error: Argument for $1 is missing" >&2
          exit 1
        fi
        ;;
      -v)
        echo "$OLLAMA_MULTIRUN_NAME v$OLLAMA_MULTIRUN_VERSION"
        exit 0
        ;;
      -*) # unsupported flags
        echo "Error: unsupported argument: $1" >&2
        exit 1
        #shift 1
        ;;
      *) # preserve positional arguments
        prompt+="$1"
        shift
        ;;
    esac
  done
  # set positional arguments in their proper place
  eval set -- "$prompt"
}

getDateTime() {
  date '+%Y-%m-%d %H:%M:%S'
}

setModels() {
  models=($(ollama list | awk '{if (NR > 1) print $1}' | sort)) # Get list of models, sorted alphabetically
  if [ -z "${models[*]}" ]; then
    echo "No models found. Please install models with 'ollama pull <model-name>'" >&2
    exit 1
  fi

  parsedModels=()
  if [ -n "$modelsList" ]; then
    IFS=',' read -ra modelsListArray <<< "$modelsList" # parse csv into modelsListArray
    for m in "${modelsListArray[@]}"; do
      if [[ "${models[*]}" =~ "$m" ]]; then # if model exists
        parsedModels+=("$m")
      else
        echo "Error: model not found: $m" >&2
        exit 1
      fi
    done
  fi
  if [ -n "${parsedModels[*]}" ]; then
    models=("${parsedModels[@]}")
  fi

  echo "models:";
  echo "${models[@]}"
  echo
}

safeString() {
  local input="$1" # Get the input
  input=${input:0:120} # Truncate to first 120 characters
  input=$(echo "$input" | tr '[:upper:]' '[:lower:]') # Convert to lowercase
  input=${input// /_} # Replace spaces with underscores
  input=$(echo "$input" | sed 's/[^a-zA-Z0-9_]/_/g' | tr -cd 'a-zA-Z0-9_') # Replace non-allowed characters with underscores
  echo "$input" # Output the sanitized string
}

createOutputDirectory() {
  tag=$(safeString "$prompt")
  tagDatetime=$(date '+%Y%m%d-%H%M%S')
  outputDirectory="$resultsDirectory/${tagDatetime}_${tag}"
  echo "$(getDateTime)" "Output Directory: $outputDirectory/"
  if [ ! -d "$outputDirectory" ]; then
    if ! mkdir -p "$outputDirectory"; then
      echo "Error: Failed to create Output Directory $outputDirectory" >&2
      exit 1
    fi
  fi
}

setPrompt() {
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

savePrompt() {
  echo "$(getDateTime)" "Prompt: $prompt"

  promptFile="$outputDirectory/prompt.txt"
  echo "$(getDateTime)" "Creating Prompt Text: $promptFile"
  echo "$prompt" > "$promptFile"

  promptWords=$(wc -w < "$promptFile" | awk '{print $1}')
  promptBytes=$(wc -c < "$promptFile" | awk '{print $1}')

  promptYamlFile="$outputDirectory/$tag.prompt.yaml"
  echo "$(getDateTime)" "Creating Prompt Yaml: $promptYamlFile"
  generatePromptYaml > "$promptYamlFile"
}

generatePromptYaml() {
  # Github Prompt YAML: https://docs.github.com/en/github-models/use-github-models/storing-prompts-in-github-repositories
  cat << EOF
messages:
  - role: system
    content: ''
  - role: user
    content: |
$(while IFS= read -r line; do echo "      $line"; done <<< "$prompt")
model: ''
EOF
}

textarea() {
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
  local lines
  lines=$(printf '%s\n' "$content" | wc -l) # Get number of lines in content
  lines=$((lines + padding))
  if [ "$lines" -gt "$max" ]; then
    lines=$max
  fi
  content=$(echo "$content" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g') # Escape HTML special characters
  echo "<textarea readonly rows='$lines'>${content}</textarea>"
}

showPrompt() {
  echo "<p>Prompt: (<a href='./prompt.txt'>raw</a>) (<a href='./${tag}.prompt.yaml'>yaml</a>)"
  echo "  words:$promptWords  bytes:$promptBytes<br />"
  textarea "$prompt" 2 10 # 0 padding, max 10 lines
  echo "</p>"
}

showImages() {
  if [ -n "$addedImages" ]; then
    for image in ${addedImages}; do
      echo -n "<div class='box'>"
      echo -n "<a target='image' href='$(basename "$image")'><img src='$(basename "$image")' alt='$image' width='250' /></a>"
      echo -n "</div>"
    done
    echo -n "<br />"
  fi
}

clearModel() {
  echo "$(getDateTime)" "Clearing model session: $1"
  (
    expect \
    -c "spawn ollama run $1" \
    -c "expect \">>> \"" \
    -c 'send -- "/clear\n"' \
    -c "expect \"Cleared session context\"" \
    -c 'send -- "/bye\n"' \
    -c "expect eof" \
    ;
  ) > /dev/null 2>&1 # Suppress output
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to clear model session: $1" >&2
    # exit 1
  fi
}

stopModel() {
  echo "$(getDateTime)" "Stopping model: $1"
  if ! ollama stop "$1"; then
    echo "$(getDateTime)" "ERROR: Failed to stop model: $1" >&2
    # exit 1
  fi
}

showSortableTablesJavascript() {
    # From: https://github.com/tofsjonas/sortable/
    # License: The Unlicense - https://github.com/tofsjonas/sortable/blob/main/LICENSE
  echo '<style>
.sortable thead th:not(.no-sort){cursor:pointer}.sortable thead th:not(.no-sort)::after,.sortable thead th:not(.no-sort)::before{transition:color .1s ease-in-out;font-size:1.2em;color:rgba(0,0,0,0)}.sortable thead th:not(.no-sort)::after{margin-left:3px;content:"▸"}.sortable thead th:not(.no-sort):hover::after{color:inherit}.sortable thead th:not(.no-sort)[aria-sort=descending]::after{color:inherit;content:"▾"}.sortable thead th:not(.no-sort)[aria-sort=ascending]::after{color:inherit;content:"▴"}.sortable thead th:not(.no-sort).indicator-left::after{content:""}.sortable thead th:not(.no-sort).indicator-left::before{margin-right:3px;content:"▸"}.sortable thead th:not(.no-sort).indicator-left:hover::before{color:inherit}.sortable thead th:not(.no-sort).indicator-left[aria-sort=descending]::before{color:inherit;content:"▾"}.sortable thead th:not(.no-sort).indicator-left[aria-sort=ascending]::before{color:inherit;content:"▴"}.sortable{--stripe-color: #e4e4e4;--th-color: #fff;--th-bg: #808080;--td-color: #000;--td-on-stripe-color: #000;border-spacing:0}.sortable.sticky thead th{position:sticky;top:0;z-index:1}.sortable tbody tr:nth-child(odd){background-color:var(--stripe-color);color:var(--td-on-stripe-color)}.sortable thead th{background:var(--th-bg);color:var(--th-color);font-weight:normal;text-align:left;text-transform:capitalize;vertical-align:baseline;white-space:nowrap}.sortable td{color:var(--td-color)}.sortable td,.sortable th{padding:10px}.sortable td:first-child,.sortable th:first-child{border-top-left-radius:4px}.sortable td:last-child,.sortable th:last-child{border-top-right-radius:4px}
</style>'
  echo '<script>
function sortSortable(a,m){function n(b){if(b){if(m&&b.dataset.sortAlt)return b.dataset.sortAlt;if(b.dataset.sort)return b.dataset.sort;if(b.textContent)return b.textContent}return""}a.dispatchEvent(new Event("sort-start",{bubbles:!0}));for(var c=a.tHead.querySelector("th[aria-sort]"),k=a.tHead.children[0],p="ascending"===c.getAttribute("aria-sort"),f=a.classList.contains("n-last"),e=function(b,q,d){var g=n(q.cells[d]),r=n(b.cells[d]);if(f){if(""===g&&""!==r)return-1;if(""===r&&""!==g)return 1}var u=
+g-+r;g=isNaN(u)?g.localeCompare(r):u;return 0===g&&k.cells[d]&&k.cells[d].hasAttribute("data-sort-tbr")?e(b,q,+k.cells[d].dataset.sortTbr):p?-g:g},h=0;h<a.tBodies.length;h++){var l=a.tBodies[h],v=[].slice.call(l.rows,0);v.sort(function(b,q){var d;return e(b,q,+(null!==(d=c.dataset.sortCol)&&void 0!==d?d:c.cellIndex))});var t=l.cloneNode();t.append.apply(t,v);a.replaceChild(t,l)}a.dispatchEvent(new Event("sort-end",{bubbles:!0}))}
function sortableEventListener(a){function m(h,l){return h.nodeName===l?h:m(h.parentNode,l)}try{var n=a.shiftKey||a.altKey,c=m(a.target,"TH"),k=c.parentNode,p=k.parentNode,f=p.parentNode;if("THEAD"===p.nodeName&&f.classList.contains("sortable")&&!c.classList.contains("no-sort")){var e=k.cells;for(a=0;a<e.length;a++)e[a]!==c&&e[a].removeAttribute("aria-sort");e="descending";if("descending"===c.getAttribute("aria-sort")||f.classList.contains("asc")&&"ascending"!==c.getAttribute("aria-sort"))e="ascending";
c.setAttribute("aria-sort",e);f.dataset.timer&&clearTimeout(+f.dataset.timer);f.dataset.timer=setTimeout(function(){sortSortable(f,n)},1).toString()}}catch(h){}}document.addEventListener("click",sortableEventListener);
</script>'
}

showHeader() {
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

showFooter() {
  title="$1"
  echo "<br /><br />"
  echo "<footer>"
  echo "<p>$title</p>"
  echo "<p>Page created: $(getDateTime)</p>"
  echo "<p>Generated with: <a target='$OLLAMA_MULTIRUN_NAME' href='$URL'>$OLLAMA_MULTIRUN_NAME</a> v$OLLAMA_MULTIRUN_VERSION</p>"
  echo "</footer></body></html>"
}

createMenu() {
  local currentModel="$1"
  echo "<span class='menu'>"
  echo "<a href='models.html'>models</a>: "
  for modelName in "${models[@]}"; do
    if [ "$modelName" == "$currentModel" ]; then
      echo "<b>$modelName</b> "
    else
      echo "<a href='./$(safeString "$modelName").html'>$modelName</a> "
    fi
  done
  echo '</span>';
}

setStats() {
  statsTotalDuration=$(grep -oE "total duration:[[:space:]]+(.*)" "$modelStatsTxt" | awk '{ print $NF }')
  statsLoadDuration=$(grep -oE "load duration:[[:space:]]+(.*)" "$modelStatsTxt" | awk '{ print $NF }')
  statsPromptEvalCount=$(grep -oE "prompt eval count:[[:space:]]+(.*)" "$modelStatsTxt" | awk '{ print $4, $5 }')
  statsPromptEvalDuration=$(grep -oE "prompt eval duration:[[:space:]]+(.*)" "$modelStatsTxt" | awk '{ print $NF }')
  statsPromptEvalRate=$(grep -oE "prompt eval rate:[[:space:]]+(.*)" "$modelStatsTxt" | awk '{ print $4, $5 }')
  statsEvalCount=$(grep -oE "^eval count:[[:space:]]+(.*)" "$modelStatsTxt" | awk '{ print $3, $4 }')
  statsEvalDuration=$(grep -oE "^eval duration:[[:space:]]+(.*)" "$modelStatsTxt" | awk '{ print $NF }')
  statsEvalRate=$(grep -oE "^eval rate:[[:space:]]+(.*)" "$modelStatsTxt" | awk '{ print $3, $4 }')

  addedImages=$(grep -oE "Added image '(.*)'" "$modelStatsTxt" | awk '{ print $NF }' | sed "s/'//g")
  if [ -n "$addedImages" ]; then
    for image in ${addedImages}; do
      if ! [ -f "$outputDirectory"/"$(basename "$image")" ]; then
        echo "Copying image: $image"
        cp "$image" "$outputDirectory"
      fi
    done
  fi

  responseWords=$(wc -w < "$modelOutputTxt" | awk '{print $1}')
  responseBytes=$(wc -c < "$modelOutputTxt" | awk '{print $1}')
}

setOllamaStats() {
  ollamaVersion=$(ollama -v | awk '{print $4}')
  # ps columns: 1:NAME, 2:ID, 3:SIZE_NUM 4:SIZE_GB, 5:PROCESSOR_% 6:PROCESS_TYPE, 7:CONTEXT, 8:UNTIL
  ollamaPs=$(ollama ps | awk '{print $1, $2, $3, $4, $5, $6, $7}' | sed '1d') # Get columns from ollama ps output, skipping the header
  ollamaModel=$(echo "$ollamaPs" | awk '{print $1}') # Get the model name
  ollamaSize=$(echo "$ollamaPs" | awk '{print $3, $4}') # Get the model size
  ollamaProcessor=$(echo "$ollamaPs" | awk '{print $5, $6}') # Get the processor
  ollamaContext=$(echo "$ollamaPs" | awk '{print $7}') # Get the context size
}

setSystemStats() {
  systemArch=$(uname -m) # Get hardware platform
  systemProcessor=$(uname -p) # Get system processor
  systemOSName=$(uname -s) # Get system OS name
  systemOSVersion=$(uname -r) # Get system OS version
  setSystemMemoryStats
}

setSystemMemoryStats() {
  systemMemoryUsed="?"
  systemMemoryAvail="?"
  #echo "OS Type: $OSTYPE"
  case "$OSTYPE" in
    cygwin|msys)
      #echo "OS Type match: cygwin|msys"
      if command -v wmic >/dev/null 2>&1; then
        local totalMemKB
        totalMemKB=$(wmic OS get TotalVisibleMemorySize /value 2>/dev/null | grep -E "^TotalVisibleMemorySize=" | cut -d'=' -f2 | tr -d '\r')
        local availMemKB
        availMemKB=$(wmic OS get FreePhysicalMemory /value 2>/dev/null | grep -E "^FreePhysicalMemory=" | cut -d'=' -f2 | tr -d '\r')
        if [ -n "$totalMemKB" ] && [ -n "$availMemKB" ]; then
          local usedMemKB=$((totalMemKB - availMemKB))
          # Convert KB to human readable format (approximate)
          if [ $usedMemKB -gt 1048576 ]; then
            systemMemoryUsed="$((usedMemKB / 1048576))G"
          elif [ $usedMemKB -gt 1024 ]; then
            systemMemoryUsed="$((usedMemKB / 1024))M"
          else
            systemMemoryUsed="${usedMemKB}K"
          fi
          if [ "$availMemKB" -gt 1048576 ]; then
            systemMemoryAvail="$((availMemKB / 1048576))G"
          elif [ "$availMemKB" -gt 1024 ]; then
            systemMemoryAvail="$((availMemKB / 1024))M"
          else
            systemMemoryAvail="${availMemKB}K"
          fi
        fi
      fi
      ;;
    darwin*)
      #echo "OS Type match: darwin"
      top=$(top -l 1 2>/dev/null || echo "")
      if [ -n "$top" ]; then
        systemMemoryUsed=$(echo "$top" | awk '/PhysMem/ {print $2}' || echo "N/A")
        systemMemoryAvail=$(echo "$top" | awk '/PhysMem/ {print $6}' || echo "N/A")
      fi
      ;;
    *)
      #echo "OS Type match: *"
      top=$(top -l 1 2>/dev/null || top -bn1 2>/dev/null || echo "")
      if [ -n "$top" ]; then
        systemMemoryUsed=$(echo "$top" | awk '/PhysMem/ {print $2}' || echo "N/A")
        systemMemoryAvail=$(echo "$top" | awk '/PhysMem/ {print $6}' || echo "N/A")
      fi
      ;;
  esac
}

showSystemStats() {
  echo "<div class='box'><table>"
  echo "<tr><td class='left' colspan='2'>System</td></tr>"
  echo "<tr><td class='left'>Ollama proc</td><td class='left'>$ollamaProcessor</td></tr>"
  echo "<tr><td class='left'>Ollama context</td><td class='left'>$ollamaContext</td></tr>"
  echo "<tr><td class='left'>Ollama version</td><td class='left'>$ollamaVersion</td></tr>"
  echo "<tr><td class='left'>Multirun timeout</td><td class='left'>$TIMEOUT seconds</td></tr>"
  echo "<tr><td class='left'>Sys arch</td><td class='left'>$systemArch</td></tr>"
  echo "<tr><td class='left'>Sys processor</td><td class='left'>$systemProcessor</td></tr>"
  echo "<tr><td class='left'>sys memory</td><td class='left'>$systemMemoryUsed + $systemMemoryAvail</td></tr>"
  echo "<tr><td class='left'>Sys OS</td><td class='left'>$systemOSName $systemOSVersion</td></tr>"
  echo "</table></div>"
}

createModelInfoTxt() { # Create model info files - for each model, do 'ollama show' and save the results to text file
  for model in "${models[@]}"; do
    modelInfoTxt="$outputDirectory/$(safeString "$model").info.txt"
    echo "$(getDateTime)" "Creating Model Info Text: $modelInfoTxt"
    ollama show "$model" > "$modelInfoTxt"
  done
}

setModelInfo() {
  modelInfoTxt="$outputDirectory/$(safeString "$model").info.txt"
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
  done < "$modelInfoTxt"
}

createModelsOverviewHtml() {
  # list of models used in current run
  modelsIndexHtml="$outputDirectory/models.html"
  echo "$(getDateTime)" "Creating Models Index Page: $modelsIndexHtml"
  {
    showHeader "$OLLAMA_MULTIRUN_NAME: models"
    titleLink="<a href='../index.html'>$OLLAMA_MULTIRUN_NAME</a>: <a href='./index.html'>$tag</a>: <b>models</b>: $tagDatetime"
    echo "<header>$titleLink</header>"
    cat <<- EOF
<br />
<table class='sortable'>
  <thead>
    <tr>
      <th class='left'>Model</th>
      <th>Architecture</th>
      <th>Parameters</th>
      <th>Context<br />length</th>
      <th>Embedding<br />length</th>
      <th>Quantization</th>
      <th>Temperature</th>
      <th>Capabilities</th>
      <th class='left'>System prompt</th>
      <th class='no-sort'>(raw)</th>
      <th class='no-sort'>(index)</th>
    </tr>
  </thead>
  <tbody>
EOF
  } > "$modelsIndexHtml"

  for model in "${models[@]}"; do
    setModelInfo
    {
      echo "<tr>"
      echo "<td class='left'><a href='./$(safeString "$model").html'>$model</a></td>"
      echo "<td>$modelArchitecture</td>"
      echo "<td>$modelParameters</td>"
      echo "<td>$modelContextLength</td>"
      echo "<td>$modelEmbeddingLength</td>"
      echo "<td>$modelQuantization</td>"
      echo "<td>$modelTemperature</td>"
      echo "<td class='left'>$(printf "%s<br />" "${modelCapabilities[@]}")</td>"
      echo "<td class='left'>$modelSystemPrompt</td>"
      echo "<td><a href='./$(safeString "$model").info.txt'>raw</a></td>"
      echo "<td><a href='../models.html#$(safeString "$model")'>index</a></td>"
      echo "</tr>"
    } >> "$modelsIndexHtml"
  done

  {
    echo "</tbody></table>"
    showSortableTablesJavascript
    showFooter "$titleLink"
  } >> "$modelsIndexHtml"
}

createModelOutputHtml() {
  modelHtmlFile="$outputDirectory/$(safeString "$model").html"
  echo "$(getDateTime)" "Creating Model Output Page: $modelHtmlFile"
  {
    showHeader "$OLLAMA_MULTIRUN_NAME: $model"
    titleLink="<a href='../index.html'>$OLLAMA_MULTIRUN_NAME</a>: <a href='./index.html'>$tag</a>: <b>$model</b>: $tagDatetime"
    echo "<header>$titleLink<br /><br />"
    createMenu "$model"
    echo "</header>"
    showPrompt
    showImages

    modelThinkingTxt="$outputDirectory/$(safeString "$model").thinking.txt"
    if [ -f "$modelThinkingTxt" ]; then
      echo "<p>Thinking: $model (<a href='./$(safeString "$model").thinking.txt'>raw</a>)<br />"
      textarea "$(cat "$modelThinkingTxt")" 3 15 # 3 padding, max 15 lines
      echo "</p>"
    fi

    echo "<p>Output: $model (<a href='./$(safeString "$model").output.txt'>raw</a>)<br />"
    textarea "$(cat "$modelOutputTxt")" 3 25 # 3 padding, max 25 lines
    echo "</p>"

    echo "<div class='box'><table>"
    echo "<tr><td class='left' colspan='2'>Stats (<a href='./$(safeString "$model").stats.txt'>raw</a>)</td></tr>"
    echo "<tr><td class='left'>Words</td><td>$responseWords</td></tr>"
    echo "<tr><td class='left'>Bytes</td><td>$responseBytes</td></tr>"
    echo "<tr><td class='left'>Total duration</td><td>$statsTotalDuration</td></tr>"
    echo "<tr><td class='left'>Load duration</td><td>$statsLoadDuration</td></tr>"
    echo "<tr><td class='left'>Prompt eval count</td><td>$statsPromptEvalCount</td></tr>"
    echo "<tr><td class='left'>Prompt eval duration</td><td>$statsPromptEvalDuration</td></tr>"
    echo "<tr><td class='left'>Prompt eval rate</td><td>$statsPromptEvalRate</td></tr>"
    echo "<tr><td class='left'>Eval count</td><td>$statsEvalCount</td></tr>"
    echo "<tr><td class='left'>Eval duration</td><td>$statsEvalDuration</td></tr>"
    echo "<tr><td class='left'>Eval rate</td><td>$statsEvalRate</td></tr>"
    echo "</table></div>"

    echo "<div class='box'><table>"
    echo "<tr><td class='left' colspan='2'>Model (<a href='./$(safeString "$model").info.txt'>raw</a>)</td></tr>"
    echo "<tr><td class='left'>Name</td><td class='left'><a href='../models.html#$(safeString "$model")'>$model</a></td></tr>"
    echo "<tr><td class='left'>Architecture</td><td class='left'>$modelArchitecture</td></tr>"
    echo "<tr><td class='left'>Size</td><td class='left'>$ollamaSize</td></tr>"
    echo "<tr><td class='left'>Parameters</td><td class='left'>$modelParameters</td></tr>"
    echo "<tr><td class='left'>Context length</td><td class='left'>$modelContextLength</td></tr>"
    echo "<tr><td class='left'>Embedding length</td><td  class='left'>$modelEmbeddingLength</td></tr>"
    echo "<tr><td class='left'>Quantization</td><td class='left'>$modelQuantization</td></tr>"
    echo "<tr><td class='left'>Capabilities</td><td class='left'>$(printf "%s<br />" "${modelCapabilities[@]}")</td>"
    echo "</table></div>"

    showSystemStats

    showFooter "$titleLink"
  } > "$modelHtmlFile"
}

createOutputIndexHtml() {
  outputIndexHtml="$outputDirectory/index.html"
  echo "$(getDateTime)" "Creating Output Index Page: $outputIndexHtml"
  {
    showHeader "$OLLAMA_MULTIRUN_NAME: $tag"
    titleLink="<a href='../index.html'>$OLLAMA_MULTIRUN_NAME</a>: <b>$tag</b>: $tagDatetime"
    echo "<header>$titleLink<br /><br />"
    createMenu "index"
    echo  "</header>"
    showPrompt
    echo "<!-- IMAGES -->"
    cat <<- "EOF"
<table class='sortable'>
  <thead>
    <tr>
      <th class='left'>Model</th>
      <th>Response<br />words</th>
      <th>Response<br />bytes</th>
      <th>Total<br />duration</th>
      <th>Load<br />duration</th>
      <th>Prompt eval<br />count</th>
      <th>Prompt eval<br />duration</th>
      <th>Prompt eval<br />rate</th>
      <th>Eval<br />count</th>
      <th>Eval<br />duration</th>
      <th>Eval<br />rate</th>
      <th>Model<br />params</th>
      <th>Model<br />size</th>
      <th>Model<br />context</th>
      <th>Ollama<br />context</th>
      <th>Ollama<br />proc</th>
    </tr>
  </thead>
  <tbody>
EOF
  } > "$outputIndexHtml"
}

addModelToOutputIndexHtml() {
  (
    echo "<tr>"
    echo "<td class='left'><a href='./$(safeString "$model").html'>$model</a></td>"
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
    echo "<td>$modelParameters</td>"
    echo "<td>$ollamaSize</td>"
    echo "<td>$modelContextLength</td>"
    echo "<td>$ollamaContext</td>"
    echo "<td>$ollamaProcessor</td>"
    echo "</tr>"
  ) >> "$outputIndexHtml"
}

finishOutputIndexHtml() {
  {
    echo "</tbody></table>"
    echo "<br /><br />"
    showSystemStats
    showSortableTablesJavascript
    titleLink="<a href='../index.html'>$OLLAMA_MULTIRUN_NAME</a>: <b>$tag</b>: $tagDatetime"
    showFooter "$titleLink"
  } >> "$outputIndexHtml"

  imagesHtml=$(showImages)
  sed -i '' -e "s#<!-- IMAGES -->#${imagesHtml}#" "$outputIndexHtml"
}

getSortedResultsDirectories() {
  # Sort directories by datetime at end of directory name
  ls -d "$resultsDirectory"/* | awk 'match($0, /[0-9]{8}-[0-9]{6}$/) { print $0, substr($0, RSTART, RLENGTH) }' | sort -k2 -r | cut -d' ' -f1
}

createMainIndexHtml() {
  resultsIndexFile="${resultsDirectory}/index.html"
  echo "$(getDateTime)" "Creating Main Index Page: $resultsIndexFile"
  {
    showHeader "$OLLAMA_MULTIRUN_NAME: results"
    titleLink="<b>$OLLAMA_MULTIRUN_NAME</b>"
    echo "<header>$titleLink</header>"
    echo "<p><a href='models.html'>Models Index</a></p>"
    echo "<p>Runs:<ul>"
    for dir in $(getSortedResultsDirectories); do
      if [ -d "$dir" ]; then
        echo "<li><a href='${dir##*/}/index.html'>${dir##*/}</a></li>"
      fi
    done
    echo "</ul></p>"
    showFooter "$titleLink"
  } > "$resultsIndexFile"
}

createMainModelIndexHtml() {
  # create table of contents: list all models used in all run results, and links to every individual model run
  modelsFound=()
  modelsIndex=()

  for dir in $(getSortedResultsDirectories); do # for each item in main results directory
    if [ -d "$dir" ]; then # if is a directory
      for file in "$dir"/*.html; do # for each *.html file in the directory
        if [[ $file != *"/index.html" && $file != *"/models.html" ]]; then # skip index.html and models.html
          fileName="${file##*/}"
          modelName="${fileName%.html}" # remove .html to get model name
          if [[ ! "${modelsFound[*]}" =~ "$modelName" ]]; then
            modelsFound+=("$modelName")
          fi
          modelsIndex+=("$modelName:$dir/$fileName")
        fi
      done
    fi  
  done

  mainModelIndexHtml="$resultsDirectory/models.html"
  echo; echo "$(getDateTime)" "Creating Main Model Index Page: $mainModelIndexHtml"
  {
    showHeader "$OLLAMA_MULTIRUN_NAME: Model Run Index"
    titleLink="<b><a href='index.html'>$OLLAMA_MULTIRUN_NAME</a></b>: Model Run Index"
    echo "<header>$titleLink</header>"

    echo '<p>Models: '
    for foundModel in "${modelsFound[@]}"; do
      echo "<a href='#$foundModel'>$foundModel</a> "
    done
    echo '</p>'

    echo "<ul>"
    for foundModel in "${modelsFound[@]}"; do
      echo " <li id='$foundModel'>$foundModel</li>"
      echo "  <ul>"
      for modelIndex in "${modelsIndex[@]}"; do
        modelName=${modelIndex%%:*} # get everything before the :
        if [ "$modelName" == "$foundModel" ]; then
          run=${modelIndex#*:} # get everything after the :
          runLink="${run#"$resultsDirectory"/}" # remove the results directory from beginning
          runName="${runLink%/*}" # remove everything after last slash including the slash
          echo "   <li><a href='$runLink'>$runName</a></li>"
        fi
      done
      echo '  </ul>'
    done
    echo "</ul>"
    echo "<p><a href='./models.html'>top</a></p>"
    showFooter "$titleLink"
  } > "$mainModelIndexHtml"
}

runModelWithTimeout() {
  echo "$prompt" | ollama run --verbose "${model}" > "${modelOutputTxt}" 2> "${modelStatsTxt}" &
  pid=$!
  (
    sleep "$TIMEOUT"
    if kill -0 $pid 2>/dev/null; then
      echo "[ERROR: Multirun Timeout after ${TIMEOUT} seconds]" > "${modelOutputTxt}"
      kill $pid 2>/dev/null
    fi

  ) &
  timeout_pid=$!

  # Wait for the main process to complete
  if wait $pid 2>/dev/null; then
    # Main process completed successfully, kill the timeout process
    if kill -0 $timeout_pid 2>/dev/null; then
      kill $timeout_pid 2>/dev/null
      wait $timeout_pid 2>/dev/null  # Clean up the timeout process
    fi
  else
    # Main process was killed (likely by timeout), wait for timeout process
    wait $timeout_pid 2>/dev/null
  fi

}

parseThinkingOutput() {
  local modelThinkingTxt
  modelThinkingTxt="$outputDirectory/$(safeString "$model").thinking.txt"

  # Check for either <think> tags or Thinking... patterns
  if grep -q -E "(<think>|Thinking\.\.\.)" "$modelOutputTxt"; then
    #echo "Found thinking content in $modelOutputTxt, extracting..."

    # Read the entire file content
    local content
    content=$(cat "$modelOutputTxt")

    # Extract thinking content
    local thinkingContent=""
    thinkingContent+=$(echo "$content" | sed -n '/<think>/,/<\/think>/p' | sed '1d;$d')
    thinkingContent+=$(echo "$content" | sed -n '/Thinking\.\.\./,/\.\.\.done thinking\./p' | sed '1d;$d')

    # Remove thinking content from original
    content=$(echo "$content" | sed '/<think>/,/<\/think>/d')
    content=$(echo "$content" | sed '/Thinking\.\.\./,/\.\.\.done thinking\./d')

    echo "$(getDateTime)" "Creating Thinking Text: $modelThinkingTxt"
    echo "$thinkingContent" > "$modelThinkingTxt"

    echo "$(getDateTime)" "Updating Model Output Text: $modelOutputTxt"
    echo "$content" > "$modelOutputTxt"
  fi
}

export OLLAMA_MAX_LOADED_MODELS=1

parseCommandLine "$@"
echo; echo "$OLLAMA_MULTIRUN_NAME v$OLLAMA_MULTIRUN_VERSION"; echo
setModels
setPrompt
echo; echo "$(getDateTime)" "Response Timeout: $TIMEOUT"
createOutputDirectory
createMainIndexHtml
savePrompt
createModelInfoTxt
createModelsOverviewHtml
setSystemStats
createOutputIndexHtml
for model in "${models[@]}"; do # Loop through each model and run it with the given prompt
  echo; echo "$(getDateTime)" "Running model: $model"
  # clearModel "$model" - not needed?
  modelOutputTxt="$outputDirectory/$(safeString "$model").output.txt"
  modelStatsTxt="$outputDirectory/$(safeString "$model").stats.txt"
  echo "$(getDateTime)" "Creating Model Output Text: $modelOutputTxt"
  echo "$(getDateTime)" "Creating Model Stats Text: $modelStatsTxt"
  runModelWithTimeout
  setSystemMemoryStats
  setOllamaStats
  parseThinkingOutput
  setModelInfo
  setStats
  createModelOutputHtml
  addModelToOutputIndexHtml
  stopModel "$model"
done
finishOutputIndexHtml
createMainModelIndexHtml
echo; echo "$(getDateTime)" "Done: $outputDirectory/"
