# ollama-multirun tests

This directory contains the tests for `ollama-multirun`. The tests are written using `bats` (Bash Automated Testing System).

## Prerequisites

- `bats-core`: The tests require `bats-core` to be installed and available in your `PATH`.
- `bats-support`: The tests also require the `bats-support` library.
- `bats-assert`: The tests also require the `bats-assert` library.

Please refer to the official `bats-core` documentation for installation instructions.

## Running the tests

The tests can be run in two modes: `static` and `live`.

### Static mode (default)

Static mode is the default. It uses mocks for external commands like `ollama`. This allows you to run the tests without having `ollama` installed or an internet connection.

To run the tests in static mode:

```bash
bats tests/multirun.bats
```

### Live mode

Live mode runs the tests against a real `ollama` installation. This requires `ollama` to be installed and running, and an internet connection.

To run the tests in live mode, set the `BATS_TEST_MODE` environment variable to `live`:

```bash
BATS_TEST_MODE=live bats tests/multirun.bats
```

**Note:** Live mode tests will interact with your local `ollama` instance and may take some time to run.
