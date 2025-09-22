---
applyTo: "scripts/devops/**/*.sh"
---

# Github Copilot Instructions for DevOps Bash Scripts

## Core Technologies and Libraries for Shell Scripting

- **Shell Interpreter**: #!/bin/bash
- **Output Library**: scripts/devops/bash/lib/output-utils.sh
- **Logging Library:**: scripts/devops/bash/lib/logging/watts/logging.sh
- **Master Template**: scripts/devops/bash/templates/bash-script.template.sh

## 1. Development Conventions (CRITICAL)

### 1. Basic File Structure (ENFORCED)

All bash scripts should be created out of the `scripts/devops/bash/templates/bash-script.template.sh` file, which has the following structure, MAIN_LOGIC should be replaced by a more reable name that states what the main script does:

```bash
#!/bin/bash
set -euo pipefail

# Script metadata (required)
# @file script-name.sh
# @brief Brief description of what the script does
# @description Detailed description
# @usage ./script-name.sh -o <org> [--json]
# @exitcodes 0:Success 1:Error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/output-utils.sh"

# Global variables (parameters only)
TARGET_ORG=""
JSON_OUTPUT=false

show_usage() { ... }
parse_args() { ... }
validate_args() { ... }
check_dependencies() { ... }
MAIN_LOGIC() { ... }

main() {
    [ $# -eq 0 ] && { show_usage; exit 1; }
    parse_args "$@"
    validate_args
    check_dependencies
    MAIN_LOGIC
}

main "$@"
```

**Critical structural requirements:**

- **Metadata block**: Include `@file`, `@brief`, `@description`, `@usage`, `@exitcodes`
- **Strict mode**: `set -euo pipefail` catches errors early
- **Directory resolution**: Always resolve `SCRIPT_DIR` for reliable sourcing
- **Function order**: parse_args → validate_args → check_dependencies → main_logic
- **No-args check**: Show usage when called without arguments

### 2. Stream Handling (ENFORCED)

**Critical separation principles:**

- **stdout**: Final results, JSON output, structured data that scripts/automation consume
- **stderr**: Progress updates, debug traces, human-readable diagnostics only
- **Exit codes**: Primary error signaling mechanism—never parse stderr for errors

```bash
# Results and structured output → stdout
print_standard_json "OK" "Success message" "$DATA"
echo "deployment-id-12345" # Consumable by calling scripts
```

```bash
# Progress and diagnostics → stderr
echo "Processing... Job ID: $JOB_ID" >&2
echo "Debug: Variable X is set to $X" >&2
```

```bash
# Error handling via exit codes
RESULT=$(sf org display --json 2> /dev/null) || {
        echo "Error: Failed to query org" >&2
        exit 1
}
```

```bash
# Capture command output cleanly
if ! SF_OUTPUT=$(sf org list --json 2> /dev/null); then
        echo "Error: SF CLI command failed" >&2
        exit 1
fi
```

**Stream redirection best practices:**

- Suppress expected stderr: `2>/dev/null` for clean automation
- Preserve separation: Never mix result data with progress messages
- Reliable integration: Calling processes should capture stdout, ignore stderr

### 3. Variable Management (ENFORCED)

**Global scope**: Script parameters and configuration only  
**Local scope**: All other variables must be `local`

```bash
# Acceptable globals
TARGET_ORG=""
JSON_OUTPUT=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function with local variables
validate_component() {
        local component_id="$1"
        local component_json="$2"
        # ...
}

# AVOID: reinitializing globals in functions
parse_args() {
        JSON_OUTPUT=false # Don't do this
}
```

**Naming conventions**:

- **UPPERCASE_SNAKE_CASE**: Global variables, constants, function arguments
- **lowercase**: Short-lived loop variables
- **Boolean flags**: Use `IS_`, `HAS_`, or `USE_` prefixes for clarity

**Additional requirements**:

- **Quote expansions**: Always use `"$VAR"` unless you intentionally want word splitting
- **Descriptive names**: Prefer `SOURCE_FILE` over `SF` for clarity
- **Arrays**: Use plural names (`FILES`, `USER_IDS`) and `_MAP` suffix for associative arrays
- **Function purity**: Functions should operate on arguments and local variables only
- **Global scope discipline**: Reduces accidental overwrites and improves maintainability

```bash
# Variable naming examples
LOG_FILE="output.log"
IS_DEBUG=true
declare -a FILES
declare -A USER_MAP

# Proper quoting and short-lived variables
for idx in "${!FILES[@]}"; do
        echo "${FILES[$idx]}" # Always quote expansions
done
```

### 4. Function Conventions (ENFORCED)

**Write functions as pure as possible for testability and maintainability.**

```bash
# Pure extraction function - operates only on arguments
get_component_id() {
        local component_json="$1"
        echo "$component_json" | jq -r '.result.records[0].Id // empty'
}
```

```bash
# Validation function - may exit, includes error context
check_component_id() {
        local component_id="$1"
        local component_json="$2" # Original data for error reporting
        local json_output="$3"

        if [ -z "$component_id" ] || [ "$component_id" = "null" ]; then
                local msg="Could not find component ID"
                if [ "$json_output" = true ]; then
                        print_error_json "$msg" "$component_json" "ID_NOT_FOUND"
                else
                        print_error_block "$msg" "$component_json" "ID_NOT_FOUND"
                fi
                exit 1
        fi
}

# AVOID: Functions that read/write arbitrary globals
bad_function() {
        # Don't access random global variables
        if [ "$SOME_GLOBAL" = "value" ]; then # Anti-pattern
                ANOTHER_GLOBAL="modified"            # Anti-pattern
        fi
}
```

**Function design principles**:

- **Purity**: Operate on arguments and local variables only
- **Global access**: Only read/modify globals intended for script parameters or status
- **Self-contained**: All function logic should be independent and testable
- **Return strategy**: Use output for data, exit codes for errors
- **Local variables**: Always declare function variables as `local`

**Function type guidelines**:

- **Extraction functions**: Pure, focused, handle edge cases with `// empty`, never exit
- **Validation functions**: Accept extracted value first, include original data for error context
- **Action functions**: May modify global status, perform side effects, may exit
- **Utility functions**: Pure helpers that transform or process data

**Benefits of pure functions**:

- **Testability**: Can be tested in isolation
- **Maintainability**: Changes don't create unexpected side effects
- **Predictability**: Same inputs always produce same outputs
- **Reusability**: Can be used in different contexts safely

### 5. Error Handling (ENFORCED)

**Exit codes indicate success/failure, not stderr parsing.**

```bash
# Command execution with status capture
local output status=0
output=$(sf org display --json 2> /dev/null) || status=$?

# Early return pattern
validate_deployment() {
        local deploy_output="$1"
        if echo "$deploy_output" | jq -e '.status' | grep -q "ERROR"; then
                echo "$deploy_output"
                return 0 # Early return, don't exit script
        fi
        echo "$deploy_output"
}
```

**Function return strategy**:

- **Data functions**: Return data via stdout, never exit
- **Validation functions**: May exit on error with clear error messages
- **Action functions**: May exit on critical errors, use early return for recoverable issues

```bash
# Data function - returns data, never exits
get_component_id() {
        local component_json="$1"
        echo "$component_json" | jq -r '.result.records[0].Id // empty'
}
```

```bash
# Data function - returns data, never exits
# Validation function - may exit with error context
check_component_id() {
        local component_id="$1"
        local component_json="$2"
        local json_output="$3"

        if [ -z "$component_id" ] || [ "$component_id" = "null" ]; then
                local msg="Could not find component ID"
                if [ "$json_output" = true ]; then
                        print_error_json "$msg" "$component_json" "ID_NOT_FOUND"
                else
                        print_error_block "$msg" "$component_json" "ID_NOT_FOUND"
                fi
                exit 1
        fi
}
```

```bash
# Action function - early return for recoverable errors
start_deployment() {
        local deploy_output
        deploy_output=$(sf project deploy start --async --json)
        local status=$?

        if [ $status -ne 0 ] || echo "$deploy_output" | jq -e '.status' | grep -q "ERROR"; then
                echo "$deploy_output" # Return error output for caller to handle
                return 0              # Early return, don't exit script
        fi
        echo "$deploy_output"
}
```

**Error propagation patterns**:

```bash
# Capture both output and exit status
local component_json fetch_status=0
component_json=$(fetch_component_data "$OBJECT" "$FIELD" "$VALUE") || fetch_status=$?
check_fetch_result "$fetch_status" "$component_json" "$JSON_OUTPUT"
```

```bash
# Command execution with conditional error handling
if ! final_result=$(sf org display --json 2> /dev/null); then
        echo "Error: Failed to query org" >&2
        exit 1
fi
```

```bash
# Multiple command coordination
deploy_output=$(start_deployment "$SOURCE_DIR" "$TARGET_ORG")
if echo "$deploy_output" | jq -e '.status' | grep -q "ERROR"; then
        # Handle deployment start failure
        output_error_and_exit "$deploy_output"
fi
```

**Key principles**:

- **Exit codes first**: Use exit codes to signal errors, not stderr content
- **Context preservation**: Include original data in error messages for debugging
- **Graceful degradation**: Use early returns for recoverable errors
- **Clear separation**: Data functions don't exit, validation functions may exit
- **Error context**: Always provide actionable error messages with relevant details

### 6. Extract-then-Validate Pattern (ENFORCED)

**Separate data extraction from validation for robust error handling.**

```bash
# Step 1: Extract (pure function)
get_job_id() {
        local output="$1"
        echo "$output" | jq -r '.result.id // .result.scratchOrgInfo.Id // empty'
}

# Step 2: Validate (handles errors and exits)
check_job_id() {
        local job_id="$1"
        local output="$2"
        local json_mode="$3"

        if [ -z "$job_id" ] || [ "$job_id" = "null" ]; then
                local msg="Could not extract job ID from command output"
                if [ "$json_mode" = true ]; then
                        print_error_json "$msg" "$output" "NO_JOB_ID"
                else
                        print_error_block "$msg" "$output" "NO_JOB_ID"
                fi
                exit 1
        fi
}

# Usage
JOB_ID=$(get_job_id "$CREATE_OUTPUT")
check_job_id "$JOB_ID" "$CREATE_OUTPUT" "$JSON_OUTPUT"
```

**Key benefits**:

- **Clear separation**: Extraction logic separate from validation logic
- **Reusability**: Extraction functions work in multiple contexts
- **Testability**: Each function can be tested independently
- **Maintainability**: Changes don't affect each other
- **Context-aware errors**: Validation provides detailed error messages

**Critical anti-pattern to avoid**:

```bash
# DON'T: Combine extraction and validation
if [ -z "$(echo "$JSON" | jq -r '.result.id // empty')" ]; then
        echo "Error: Could not find ID"
        exit 1 # Caller code never runs!
fi

# DON'T: Functions that exit immediately
get_and_validate_id() {
        local json="$1"
        local id
        id=$(echo "$json" | jq -r '.result.id // empty')
        [ -z "$id" ] && exit 1 # Script terminates, no cleanup possible
        echo "$id"
}
```

### 7. Asynchronous Command Pattern (ENFORCED)

**Three-phase pattern for long-running Salesforce operations:**

1. **Start**: Execute with `--async`
2. **Monitor**: Show progress to stderr
3. **Capture**: Get final result with `report`

```bash
# Phase 1: Start
start_deployment() {
        sf project deploy start --source-dir "$1" --target-org "$2" --async --json
}

# Phase 2: Monitor (stderr)
show_progress() {
        local job_id="$1"
        echo "Deployment started. Job ID: $job_id" >&2
        sf project deploy resume --job-id "$job_id" --wait 30 >&2
}

# Phase 3: Capture (stdout)
get_final_result() {
        local job_id="$1"
        local fallback_output="$2"

        # Preferred: Use report for final status
        if ! sf project deploy report --job-id "$job_id" --json 2> /dev/null; then
                # Fallback to resume
                if ! sf project deploy resume --job-id "$job_id" --json 2> /dev/null; then
                        # Last resort: original output
                        echo "$fallback_output"
                fi
        fi
}
```

**Supported async commands**:

- `sf project deploy start --async` → `sf project deploy resume --job-id <ID>`
- `sf org create scratch --async` → `sf org resume scratch --job-id <ID>`
- `sf data import bulk --async` → `sf data import bulk resume --job-id <ID>`
- `sf data export bulk --async` → `sf data export bulk resume --job-id <ID>`

**Stream redirection strategy**:

```bash
# Progress monitoring → stderr (for human operators)
sf project deploy resume --job-id "$JOB_ID" --wait 30 >&2

# Result capture → stdout (for automation/processing)
FINAL_JSON=$(sf project deploy report --job-id "$JOB_ID" --json 2> /dev/null)
```

**Key benefits**:

- **Progress visibility**: Users see real-time progress without interfering with result capture
- **Clean automation**: Final JSON result is cleanly captured for processing
- **Error isolation**: Noise from resume command is suppressed during result capture
- **Robust fallbacks**: Multiple strategies for capturing final results

**Job ID handling pattern**:

```bash
# Extract job ID using Extract-then-Validate pattern
JOB_ID=$(get_job_id "$DEPLOY_OUTPUT")
check_job_id "$JOB_ID" "$DEPLOY_OUTPUT" "$JSON_OUTPUT"

# Job ID extraction function
get_job_id() {
        local output="$1"
        echo "$output" | jq -r '.result.id // .result.scratchOrgInfo.Id // empty'
}
```

**Complete async operation flow**:

1. **Start** async operation and capture initial output
2. **Extract and validate** job ID from start output
3. **Monitor** progress via resume command to stderr
4. **Capture** final result via report command to stdout
5. **Fallback** to resume or original output if report fails

### 8. Dependencies and JSON Processing (ENFORCED)

**Required tools**: `jq`, `sf`

```bash
check_dependencies() {
        command -v jq > /dev/null 2>&1 || {
                print_error_json "jq is required but not installed" "" "MISSING_DEPENDENCY"
                exit 1
        }
}

# Safe JSON processing
echo "$data" | jq -r '.result.records[0].Id // empty'

# JSON validation
echo "$output" | jq empty 2> /dev/null || handle_invalid_json
```

---

**Key Principles**:

- **Strict mode**: Always use `set -euo pipefail`
- **Pure functions**: Extract-then-validate pattern
- **Stream separation**: Results to stdout, progress to stderr
- **Global scope**: Parameters only, everything else local
- **Error handling**: Exit codes, not message parsing
- **Async operations**: Start → Monitor → Capture pattern

## 2. Output Specification (CRITICAL)

The library that enforces this standard is located at scripts/devops/bash/lib/output-utils.sh

### Specification Metadata

| Property    | Value                                                                                                                                                                            |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Title**   | CLI Output Specification                                                                                                                                                         |
| **Version** | 0.1.1                                                                                                                                                                            |
| **Date**    | 2025-06-17                                                                                                                                                                       |
| **Author**  | metasintaxis                                                                                                                                                                     |
| **License** | MIT                                                                                                                                                                              |
| **Scope**   | CLI script output formatting                                                                                                                                                     |
| **Purpose** | To define a unified, extensible, and machine/human-friendly output structure for CLI scripts, supporting both interactive use and automated pipelines in demanding environments. |

---

### Standard Output Schema

All script outputs—whether standard or error—must use the following fields for consistency, traceability, and ease of parsing:

| Field       | Type   | Required | Notes                                                                                |
| ----------- | ------ | -------- | ------------------------------------------------------------------------------------ |
| `status`    | string | Yes      | `OK`, `WARNING`, or `ERROR`                                                          |
| `message`   | string | Yes      | Human-readable summary                                                               |
| `detail`    | any    | No       | Main result, extra context, or error details (can be any type, e.g., JSON)           |
| `timestamp` | string | Yes      | ISO 8601 format (e.g., `2025-06-17T19:12:10Z`)                                       |
| `errorCode` | string | No       | Error identifier, present only for errors                                            |
| `line`      | int    | No       | Line number where the error occurred (errors only, recommended)                      |
| `script`    | string | No       | Script filename (errors only, recommended)                                           |
| `function`  | string | No       | Name of the function where the output or error originated (errors only, recommended) |

- **Note:** The `detail` field is generic and may contain any relevant data, including embedded JSON from other commands, error stack traces, or additional context.
- The `line`, `script`, and `function` fields are recommended for error outputs to aid diagnostics and traceability.

---

### Human-Readable Block Output

Scripts **must** emit a human-friendly block format for interactive use.  
If the `detail` field contains complex or multi-line data (such as JSON), it should be pretty-printed and indented for clarity.

**Example (simple detail):**

```text
Timestamp : 2025-06-16T12:00:00Z
Status    : OK
Message   : Operation completed
Detail    : 42
-------------------------------
```

**Example (complex detail):**

```text
Timestamp : 2025-06-17T19:12:10Z
Status    : OK
Message   : Fetched org info
Detail    :
{
  "orgId": "00D...",
  "username": "user@example.com"
}
-------------------------------
```

**Example (error):**

```text
Timestamp : 2025-06-16T12:01:00Z
Status    : ERROR
Message   : Invalid input
Detail    : Missing 'name' field
Error Code: E001
Line      : 42
Script    : my-script.sh
Function  : validate_args
-------------------------------
```

---

## JSON Output Example

```json
{
        "status": "OK",
        "message": "Operation completed",
        "detail": 42,
        "timestamp": "2025-06-16T12:00:00Z"
}
```

### JSON Output Example with Embedded Object

```json
{
        "status": "OK",
        "message": "Fetched org info",
        "detail": {
                "orgId": "00D...",
                "username": "user@example.com"
        },
        "timestamp": "2025-06-17T19:12:10Z"
}
```

### JSON Error Output Example

```json
{
        "status": "ERROR",
        "message": "Invalid input",
        "detail": "Missing 'name' field",
        "timestamp": "2025-06-16T12:01:00Z",
        "errorCode": "E001",
        "line": 42,
        "script": "my-script.sh",
        "function": "validate_args"
}
```

---

### Security, Traceability, and Reliability Considerations

- **Timestamps** must always be in UTC and ISO 8601 format for auditability.
- **Error reporting** should always include `line`, `script`, and `function` when possible for traceability.
- **Field presence**: Required fields must always be present; optional fields should be set to `null` or omitted if not applicable.
- **Data integrity**: Scripts must ensure that output is well-formed and valid JSON when using machine-readable output.
- **No sensitive data**: Do not include secrets, credentials, or classified information in any output field.

---

### Versioning and Compatibility

- The specification is **versioned** for stability and future enhancements.
- Backward compatibility must be maintained across `x.0` versions.
- New fields or formats must be introduced as optional and documented clearly.
- Breaking changes require a major or minor version bump.

---

### Best Practices

- Always include `status`, `message`, and `timestamp`.
- Use `detail` for both result data and error context, including embedded JSON.
- Set unused fields to `null` or omit them.
- Use `errorCode`, `line`, `script`, and `function` only for errors.
- Scripts must support both JSON and human-readable block output.
- When reporting errors, use Bash’s `${LINENO}`, `${BASH_SOURCE[0]}`, and `${FUNCNAME[0]}` to populate `line`, `script`, and `function`.
- Validate output format in CI/CD pipelines for mission-critical environments.

---

## 3. Bash Logging Module (ENFORCED)

The module that embodies the following standard is placed at scripts/devops/bash/lib/logging/watts/logging.sh

## Basic Usage

```bash
# Source the logging module
source /path/to/logging.sh

# Initialize the logger with defaults
init_logger

# Log messages at different levels
log_debug "This is a debug message"
log_info "This is an info message"
log_warn "This is a warning message"
log_error "This is an error message"
log_fatal "This is a fatal error message"
```

## Initialization Options

The `init_logger` function accepts the following options:

| Option                                          | Description                                                                         |
| ----------------------------------------------- | ----------------------------------------------------------------------------------- |
| `-l, --log, --logfile, --log-file, --file FILE` | Specify a log file to write logs to                                                 |
| `-q, --quiet`                                   | Disable console output                                                              |
| `-v, --verbose, --debug`                        | Set log level to DEBUG (most verbose)                                               |
| `-d, --level LEVEL`                             | Set log level (DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY or 0-7) |
| `-f, --format FORMAT`                           | Set custom log format                                                               |
| `-u, --utc`                                     | Use UTC time instead of local time                                                  |
| `-j, --journal`                                 | Enable logging to systemd journal                                                   |
| `-t, --tag TAG`                                 | Set custom tag for journal logs (default: script name)                              |
| `--color --colour`                              | Explicitly enable color output (default: auto-detect)                               |
| `--no-color --no-colour`                        | Disable color output                                                                |

Example:

```bash
# Initialize logger with file output, journal logging, and DEBUG level
init_logger --log "/var/log/myscript.log" --level DEBUG --journal --tag "myapp"
```

### Log Levels

The module supports standard syslog levels, from most to least severe:

| Level     | Numeric Value | Function        | Syslog Priority      |
| --------- | ------------- | --------------- | -------------------- |
| EMERGENCY | 0             | `log_emergency` | emerg                |
| ALERT     | 1             | `log_alert`     | alert                |
| CRITICAL  | 2             | `log_critical`  | crit                 |
| ERROR     | 3             | `log_error`     | err                  |
| WARN      | 4             | `log_warn`      | warning              |
| NOTICE    | 5             | `log_notice`    | notice               |
| INFO      | 6             | `log_info`      | info                 |
| DEBUG     | 7             | `log_debug`     | debug                |
| SENSITIVE | -             | `log_sensitive` | (not sent to syslog) |

Messages with a level lower than the current log level are suppressed.

Sensitive messages are logged at the INFO level but are not written to log files or the journal. They are only displayed on the console.

## Custom Log Format

You can customize the log format using special placeholders:

| Placeholder | Description   | Example                            |
| ----------- | ------------- | ---------------------------------- |
| `%d`        | Date and time | `2025-03-03 12:34:56`              |
| `%l`        | Log level     | `INFO`                             |
| `%s`        | Script name   | `myscript.sh`                      |
| `%m`        | Log message   | `Operation completed successfully` |
| `%z`        | Timezone      | `UTC` or `LOCAL`                   |

The default format is: `%d [%l] [%s] %m`

Example of custom format:

```bash
init_logger --format "[%l] %d %z [%s] %m"
```

### Runtime Configuration

You can change configuration at runtime using these functions:

```bash
# Change log level
set_log_level DEBUG    # Set to DEBUG level
set_log_level NOTICE   # Set to NOTICE level
set_log_level WARN     # Set to WARN level
set_log_level CRITICAL # Set to CRITICAL level

# Change timezone setting
set_timezone_utc true  # Use UTC time
set_timezone_utc false # Use local time

# Change log format
set_log_format "[%l] %d [%s] - %m"

# Enable/disable journal logging
set_journal_logging true  # Enable journal logging
set_journal_logging false # Disable journal logging

# Change journal tag
set_journal_tag "new-tag" # Set new tag for journal logs
```

### Journal Logging

The module can log to the systemd journal using the `logger` command. This is particularly useful for applications running as systemd services or on systems like Fedora Linux.

### Requirements

- The `logger` command must be installed (typically part of the `util-linux` package)
- The system should use systemd (standard on most modern Linux distributions)

### Configuration

Enable journal logging with the `-j` or `--journal` flag during initialization:

```bash
init_logger --journal
```

You can specify a custom tag with `-t` or `--tag`:

```bash
init_logger --journal --tag "myapp"
```

If no tag is specified, the script name is used as the default tag.

### Viewing Journal Logs

Journal logs can be viewed using the `journalctl` command:

```bash
# View logs with specific tag
journalctl -t myapp

# Follow logs in real-time
journalctl -f -t myapp

# View logs for the current boot
journalctl -b -t myapp
```

### Log Level Mapping

Log levels are mapped to syslog priorities as follows:

| Log Level | Syslog Priority |
| --------- | --------------- |
| DEBUG     | debug           |
| INFO      | info            |
| NOTICE    | notice          |
| WARN      | warning         |
| ERROR     | err             |
| CRITICAL  | crit            |
| ALERT     | alert           |
| EMERGENCY | emerg           |

## Example Use Cases

### Basic Script Logging

```bash
#!/bin/bash

# Source the logging module
source /path/to/logging.sh

# Initialize with default settings
init_logger

log_info "Script starting"
log_debug "Debug information"
# ... script operations ...
log_warn "Warning: resource usage high"
log_info "Script completed"
```

### Logging to File with Verbose Output

```bash
#!/bin/bash

# Source the logging module
source /path/to/logging.sh

# Initialize with file output and verbose mode
init_logger --log "/tmp/myapp.log" --verbose

log_info "Application starting"
log_debug "Configuration loaded" # This will be logged due to verbose mode
# ... application operations ...
log_info "Application completed"
```

### Logging to System Journal (for systemd-based systems)

```bash
#!/bin/bash

# Source the logging module
source /path/to/logging.sh

# Initialize with journal logging
init_logger --journal --tag "myservice"

log_info "Service starting"
# ... service operations ...
log_error "Error encountered: $error_message"
log_info "Service completed"
```

### Comprehensive Logging Configuration

```bash
#!/bin/bash

# Source the logging module
source /path/to/logging.sh

# Initialize with multiple outputs and custom format
init_logger \
        --log "/var/log/myapp.log" \
        --journal \
        --tag "myapp" \
        --format "%d %z [%l] [%s] %m" \
        --utc \
        --level INFO

log_info "Application initialized with comprehensive logging"
```

### Changing Log Level Based on Command-line Arguments

```bash
#!/bin/bash

# Source the logging module
source /path/to/logging.sh

# Basic initialization
init_logger

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
        case $1 in
                --debug)
                        set_log_level DEBUG
                        shift
                        ;;
                        # Other arguments...
        esac
done

log_debug "Debug mode enabled" # Only shows if --debug was passed
log_info "Normal operation"
```

**Note:** For clarity, the logger provides in `logging.sh` enables `DEBUG` logging through the `--verbose` option when called using `init_logger --verbose` however the provided `set_log_level` function accepts log levels based on their common names (DEBUG, INFO, WARN, ERROR, FATAL) or their numeric values (0, 1, 2, 3, 4). The example above uses a command line parser in the calling script to optionally enable `DEBUG` logging by accepting a local argument `--debug` and then using the `set_log_level` function to enable `DEBUG` logging.

### Advanced Usage with Custom Format and UTC Time

```bash
#!/bin/bash

# Source the logging module
source /path/to/logging.sh

# Initialize with custom format and UTC time
init_logger --format "%d %z [%l] [%s] %m" --utc

log_info "Starting processing job"

# Later, change format for a specific part of the script
set_log_format "[%l] %m"
log_info "Using simplified format"

# Return to original format
set_log_format "%d %z [%l] [%s] %m"
log_info "Back to detailed format"
```

### Logging in Functions

```bash
#!/bin/bash

source /path/to/logging.sh
init_logger --log "/var/log/myapp.log"

function process_item() {
        local item=$1
        log_debug "Processing item: $item"

        # Processing logic...
        if [[ "$item" == "important" ]]; then
                log_info "Found important item"
        fi

        # Error handling
        if [[ "$?" -ne 0 ]]; then
                log_error "Failed to process item: $item"
                return 1
        fi

        log_debug "Completed processing item: $item"
        return 0
}

log_info "Starting batch processing"
process_item "test"
process_item "important"
log_info "Batch processing complete"
```

## Sensitive Data

For sensitive data that should never be written to log files or the journal, use the `log_sensitive` function:

```bash
#!/bin/bash

source /path/to/logging.sh

init_logger --log "/var/log/myapp.log" --journal --tag "myapp"

# This will ONLY appear in the console, not in log files or journal
log_sensitive "Sensitive data: $SECRET"
```

The `log_sensitive` function will only output to the console and never to log files or the system journal. It is your responsibility to ensure that your console session is not being recorded or that any console logging is not accessible to unauthorized users.

## Exit Codes

The `init_logger` function returns:

- `0` on successful initialization
- `1` on error (e.g., unable to create log file)

## Troubleshooting

If you encounter issues:

1. Ensure that `logging.sh` is sourced using the correct path
2. Check write permissions if using file logging
3. Verify log directory exists or can be created
4. Ensure you're using valid log level names
5. For journal logging, verify the `logger` command is available
6. Check systemd journal logs with `journalctl -f` to see if logs are being received