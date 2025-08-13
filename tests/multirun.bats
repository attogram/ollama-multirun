#!/usr/bin/env bats

# Load test helpers
setup() {
  load 'bats-support/load'
  load 'bats-assert/load'

  # Source the script to be tested
  source ./multirun.sh

  # Set up mocks for static testing by default
  if [ "$BATS_TEST_MODE" != "live" ]; then
    export PATH="$(pwd)/tests:$PATH"
  fi

  # Create a temporary directory for test output
  BATS_TMPDIR=$(mktemp -d)
  resultsDirectory="$BATS_TMPDIR/results"
}

teardown() {
  # Clean up the temporary directory
  rm -rf "$BATS_TMPDIR"
}

@test "safeString: should sanitize a string" {
  result=$(safeString "This is a Test!")
  assert_equal "$result" "this_is_a_test_"
}

@test "safeString: should truncate a long string" {
  result=$(safeString "This is a very long string that should be truncated")
  assert_equal "$result" "this_is_a_very_long_string_that_should"
}

@test "safeString: should handle custom length" {
  result=$(safeString "This is a test" 10)
  assert_equal "$result" "this_is_a_"
}

@test "getDateTime: should return a date and time string" {
  result=$(getDateTime)
  assert_match "$result" "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$"
}

@test "parseCommandLine: should parse -h flag" {
  run parseCommandLine -h
  assert_success
  assert_output --partial "Usage:"
}

@test "parseCommandLine: should parse -m flag" {
  parseCommandLine -m model1,model2
  assert_equal "$modelsList" "model1,model2"
}

@test "parseCommandLine: should parse -r flag" {
  parseCommandLine -r my_results
  assert_equal "$resultsDirectory" "my_results"
}

@test "parseCommandLine: should parse -t flag" {
  parseCommandLine -t 60
  assert_equal "$TIMEOUT" "60"
}

@test "parseCommandLine: should parse -v flag" {
  run parseCommandLine -v
  assert_success
  assert_output --partial "ollama-multirun v"
}

@test "parseCommandLine: should handle prompt as argument" {
  parseCommandLine "my prompt"
  assert_equal "$prompt" "my prompt"
}

@test "setModels: should set the models array" {
  BATS_TEST_MODE=static
  setModels
  assert_equal "${models[0]}" "model1:latest"
  assert_equal "${models[1]}" "model2:latest"
}

@test "setModels: should handle specified models" {
  BATS_TEST_MODE=static
  modelsList="model1:latest"
  setModels
  assert_equal "${#models[@]}" "1"
  assert_equal "${models[0]}" "model1:latest"
}

@test "setModels: should exit if specified model not found" {
  BATS_TEST_MODE=static
  modelsList="nonexistent-model"
  run setModels
  assert_failure
  assert_output --partial "Error: model not found: nonexistent-model"
}

@test "createOutputDirectory: should create a directory" {
  prompt="my test prompt"
  createOutputDirectory
  assert [ -d "$outputDirectory" ]
}

@test "savePrompt: should save the prompt to a file" {
  prompt="my test prompt"
  createOutputDirectory
  savePrompt
  assert [ -f "$outputDirectory/prompt.txt" ]
  assert_equal "$(cat "$outputDirectory/prompt.txt")" "my test prompt"
}

@test "savePrompt: should create a yaml prompt file" {
  prompt="my test prompt"
  tag="my_test_prompt"
  createOutputDirectory
  savePrompt
  assert [ -f "$outputDirectory/my_test_prompt.prompt.yaml" ]
}

@test "generatePromptYaml: should generate a yaml prompt" {
  prompt="my test prompt"
  result=$(generatePromptYaml)
  assert_output --string "$result" --partial "content: |"
  assert_output --string "$result" --partial "my test prompt"
}

@test "textarea: should generate a textarea element" {
  result=$(textarea "my content")
  assert_equal "$result" "<textarea readonly rows='2'>my content</textarea>"
}

@test "textarea: should handle custom rows and max" {
  result=$(textarea "my\ncontent" 2 5)
  assert_equal "$result" "<textarea readonly rows='4'>my\ncontent</textarea>"
}

@test "showPrompt: should generate HTML for the prompt" {
  prompt="my test prompt"
  promptWords=3
  promptBytes=14
  tag="my_test_prompt"
  result=$(showPrompt)
  assert_output --string "$result" --partial "<p>Prompt:"
  assert_output --string "$result" --partial "my test prompt"
}

@test "clearModel: should call expect with the correct arguments" {
  BATS_TEST_MODE=static
  run clearModel "model1"
  assert_success
}

@test "stopModel: should call ollama stop" {
  BATS_TEST_MODE=static
  run stopModel "model1"
  assert_success
}

@test "showSortableTablesJavascript: should generate javascript" {
  result=$(showSortableTablesJavascript)
  assert_output --string "$result" --partial "<script>"
}

@test "showHeader: should generate HTML header" {
  result=$(showHeader "My Title")
  assert_output --string "$result" --partial "<title>My Title</title>"
}

@test "showFooter: should generate HTML footer" {
  result=$(showFooter "My Title")
  assert_output --string "$result" --partial "<footer>"
}

@test "createMenu: should generate HTML menu" {
  models=("model1" "model2")
  result=$(createMenu "model1")
  assert_output --string "$result" --partial "<b>model1</b>"
}

@test "setStats: should set stats variables" {
  BATS_TEST_MODE=static
  createOutputDirectory
  modelStatsTxt="$outputDirectory/model1.stats.txt"
  modelOutputTxt="$outputDirectory/model1.output.txt"
  echo "total duration: 1s" > "$modelStatsTxt"
  echo "output" > "$modelOutputTxt"
  setStats
  assert_equal "$statsTotalDuration" "1s"
  assert_equal "$responseWords" "1"
}

@test "setOllamaStats: should set ollama stats variables" {
  BATS_TEST_MODE=static
  setOllamaStats
  assert_equal "$ollamaVersion" "0.1.0"
}

@test "setSystemStats: should set system stats variables" {
  BATS_TEST_MODE=static
  setSystemStats
  assert_equal "$systemArch" "x86_64"
  assert_equal "$systemOSName" "Linux"
}

@test "setSystemMemoryStats: should set system memory stats" {
  BATS_TEST_MODE=static
  setSystemMemoryStats
  assert_equal "$systemMemoryUsed" "1024M"
  assert_equal "$systemMemoryAvail" "2048M"
}

@test "createModelInfoTxt: should create info files for all models" {
  BATS_TEST_MODE=static
  createOutputDirectory
  models=("model1" "model2")
  createModelInfoTxt
  assert [ -f "$outputDirectory/model1.info.txt" ]
  assert [ -f "$outputDirectory/model2.info.txt" ]
}

@test "setModelInfo: should parse model info" {
  BATS_TEST_MODE=static
  createOutputDirectory
  model="model1"
  modelInfoTxt="$outputDirectory/model1.info.txt"
  echo "architecture llama" > "$modelInfoTxt"
  echo "parameters 7B" >> "$modelInfoTxt"
  setModelInfo
  assert_equal "$modelArchitecture" "llama"
  assert_equal "$modelParameters" "7B"
}

@test "createModelsOverviewHtml: should create models overview page" {
  BATS_TEST_MODE=static
  createOutputDirectory
  models=("model1")
  createModelsOverviewHtml
  assert [ -f "$outputDirectory/models.html" ]
  assert_output --file "$outputDirectory/models.html" --partial "<title>ollama-multirun: models</title>"
}

@test "createModelOutputHtml: should create model output page" {
  BATS_TEST_MODE=static
  createOutputDirectory
  model="model1"
  modelOutputTxt="$outputDirectory/model1.output.txt"
  echo "output" > "$modelOutputTxt"
  modelStatsTxt="$outputDirectory/model1.stats.txt"
  echo "total duration: 1s" > "$modelStatsTxt"
  createModelOutputHtml
  assert [ -f "$outputDirectory/model1.html" ]
  assert_output --file "$outputDirectory/model1.html" --partial "<title>ollama-multirun: model1</title>"
}

@test "createOutputIndexHtml: should create output index page" {
  BATS_TEST_MODE=static
  prompt="my test prompt"
  tag=$(safeString "$prompt")
  createOutputDirectory
  createOutputIndexHtml
  assert [ -f "$outputDirectory/index.html" ]
  assert_output --file "$outputDirectory/index.html" --partial "<title>ollama-multirun: my_test_prompt</title>"
}

@test "addModelToOutputIndexHtml: should add a row to the index" {
  BATS_TEST_MODE=static
  prompt="my test prompt"
  tag=$(safeString "$prompt")
  createOutputDirectory
  createOutputIndexHtml
  model="model1"
  responseWords=10
  addModelToOutputIndexHtml
  assert_output --file "$outputDirectory/index.html" --partial "<td>model1</td>"
  assert_output --file "$outputDirectory/index.html" --partial "<td>10</td>"
}

@test "finishOutputIndexHtml: should finish the index page" {
  BATS_TEST_MODE=static
  prompt="my test prompt"
  tag=$(safeString "$prompt")
  createOutputDirectory
  createOutputIndexHtml
  finishOutputIndexHtml
  assert_output --file "$outputDirectory/index.html" --partial "</tbody>"
}

@test "getSortedResultsDirectories: should return sorted directories" {
  BATS_TEST_MODE=static
  mkdir -p "$resultsDirectory/test1_20250101-120000"
  mkdir -p "$resultsDirectory/test2_20250101-110000"
  result=$(getSortedResultsDirectories)
  assert_output --string "$result" --partial "test1_20250101-120000"
  assert_output --string "$result" --partial "test2_20250101-110000"
}

@test "createMainIndexHtml: should create main index page" {
  BATS_TEST_MODE=static
  mkdir -p "$resultsDirectory/test1_20250101-120000"
  createMainIndexHtml
  assert [ -f "$resultsDirectory/index.html" ]
  assert_output --file "$resultsDirectory/index.html" --partial "<b>$OLLAMA_MULTIRUN_NAME</b>"
}

@test "createMainModelIndexHtml: should create main model index page" {
  BATS_TEST_MODE=static
  mkdir -p "$resultsDirectory/test1_20250101-120000"
  touch "$resultsDirectory/test1_20250101-120000/model1.html"
  createMainModelIndexHtml
  assert [ -f "$resultsDirectory/models.html" ]
  assert_output --file "$resultsDirectory/models.html" --partial "Model Run Index"
  assert_output --file "$resultsDirectory/models.html" --partial "model1"
}

@test "runModelWithTimeout: should run a model with timeout" {
  BATS_TEST_MODE=static
  prompt="my prompt"
  model="model1"
  createOutputDirectory
  modelOutputTxt="$outputDirectory/model1.output.txt"
  modelStatsTxt="$outputDirectory/model1.stats.txt"
  runModelWithTimeout
  assert [ -f "$modelOutputTxt" ]
  assert [ -f "$modelStatsTxt" ]
}

@test "parseThinkingOutput: should parse thinking output" {
  BATS_TEST_MODE=static
  createOutputDirectory
  model="model1"
  modelOutputTxt="$outputDirectory/model1.output.txt"
  echo "<think>thinking...</think>output" > "$modelOutputTxt"
  parseThinkingOutput
  assert_equal "$(cat "$outputDirectory/model1.output.txt")" "output"
  assert [ -f "$outputDirectory/$(safeString "$model" 80).thinking.txt" ]
  assert_equal "$(cat "$outputDirectory/$(safeString "$model" 80).thinking.txt")" "thinking..."
}
