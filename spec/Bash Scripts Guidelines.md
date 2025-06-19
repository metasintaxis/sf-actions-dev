# Bash Scripts Guidelines

## Output Redirection

Scripts should select all the error and success messages to the standard output. This is because error codes already allow us to handle error messages gracefully without relying on the error output.  We reserve the error output stream to show debug logs.

## Variable Name Conventions
