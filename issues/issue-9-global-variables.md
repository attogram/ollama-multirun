# Issue 9: The script uses global variables extensively, which is poor practice

## Description
The script defines and modifies numerous global variables throughout its execution (e.g., `modelsList`, `resultsDirectory`, `prompt`, `tag`, `outputDirectory`, etc.). While this works for a small script, it makes the code harder to read, maintain, and debug, as variables can be changed from anywhere. It also prevents functions from being modular and reusable.

## Recommendation
Refactor the script to minimize the use of global variables.
1.  **Use `local`**: Declare variables inside functions with the `local` keyword to limit their scope (e.g., `local models=()`).
2.  **Pass Arguments**: Pass values to functions as arguments instead of relying on globals.
3.  **Return Values**: Have functions output their results to standard output, which can then be captured by the caller. For example, `outputDirectory=$(createOutputDirectory "$resultsDirectory" "$prompt")`.

This refactoring would significantly improve the code's quality and robustness.
