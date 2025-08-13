# Test Prompts

Some test prompts to test Ollama Multirun.

## Run Test Prompts script

Run all *.txt files in a directory with multirun:

```./run.test.prompt.sh <directory>```

examples:
- ```./run.test.prompt.sh ./code```
- ```./run.test.prompt.sh ./general```
- ```./run.test.prompt.sh ./logic```
- ```./run.test.prompt.sh ./security```
- ```./run.test.prompt.sh ./vision```

## Run individual prompts

You can also run individual prompts with `multirun.sh` directly using standard input redirection or pipes.

### From a file

```bash
./multirun.sh < test-prompts/general/hi.txt
```

### From a pipe

```bash
./test-prompts/code/review.council.sh | ./multirun.sh
```
