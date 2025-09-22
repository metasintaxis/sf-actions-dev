#!/bin/bash

# -----------------------------------------------------------------------------
# @file <script-name>.sh
# @brief <Short description of what this script does>
#
# @description
#   <Longer description of the script's purpose and behavior.>
#
# @usage
#   ./<script-name>.sh [options]
#   ./<script-name>.sh -x <example> [--json] [--log FILE] [--debug [LEVEL]]
#
# @options
#   -x, --example         Example argument description.
#   --json                Output result and errors in JSON format.
#   --log FILE            Write debug and operational logs to specified file
#   --debug [LEVEL]       Enable debug logging to stderr. Optional LEVEL:
#                         DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY
#                         (default: DEBUG if no level specified)
#   -h, --help            Show this help message and exit.
#
# @exitcodes
#   0  Success
#   1  Missing required arguments, invalid usage, or error during execution
# -----------------------------------------------------------------------------

set -euo pipefail

# Get the directory of the current script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/output-utils.sh"
source "${SCRIPT_DIR}/../lib/logging/watts/logging.sh"

# Default values for arguments
EXAMPLE_ARG=""
JSON_OUTPUT=false
DEBUG_LEVEL=""
LOG_FILE=""

show_usage() {
	echo "Usage:"
	echo "  $0 -x <example> [--json] [--log FILE] [--debug [LEVEL]]"
	echo
	echo "Options:"
	echo "  -x, --example         Example argument description."
	echo "  --json                Output result and errors in JSON format."
	echo "  --log FILE            Write debug and operational logs to specified file"
	echo "  --debug [LEVEL]       Enable debug logging to stderr. Optional LEVEL:"
	echo "                        DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY"
	echo "                        (default: DEBUG if no level specified)"
	echo "  -h, --help            Show this help message and exit."
}

parse_args() {
	EXAMPLE_ARG=""
	JSON_OUTPUT=false
	DEBUG_LEVEL=""
	LOG_FILE=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
			-x | --example)
				EXAMPLE_ARG="$2"
				shift 2
				;;
			--json)
				JSON_OUTPUT=true
				shift
				;;
			--log)
				LOG_FILE="$2"
				shift 2
				;;
			--debug)
				# Check if next argument is a log level or another flag/end of args
				if [[ $# -gt 1 && ! "$2" =~ ^- ]]; then
					# Valid log levels - convert to uppercase using tr
					local upper_level=$(echo "$2" | tr '[:lower:]' '[:upper:]')
					case "$upper_level" in
						DEBUG | INFO | NOTICE | WARN | WARNING | ERROR | ERR | CRITICAL | CRIT | ALERT | EMERGENCY | EMERG | FATAL)
							DEBUG_LEVEL="$2"
							shift 2
							;;
						*)
							# Not a valid log level, use default DEBUG
							DEBUG_LEVEL="DEBUG"
							shift
							;;
					esac
				else
					# No level specified, use default DEBUG
					DEBUG_LEVEL="DEBUG"
					shift
				fi
				;;
			-h | --help)
				show_usage
				exit 0
				;;
			*)
				show_usage >&2
				exit 1
				;;
		esac
	done
}

check_dependencies() {
	log_debug_stderr "Checking script dependencies"

	# Example: check for jq and sf
	if ! command -v jq > /dev/null 2>&1; then
		log_error_stderr "Missing dependency: jq is not installed"
		local msg="Error: jq is required but not installed."
		local detail="Install jq to continue."
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "MISSING_DEPENDENCY" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "MISSING_DEPENDENCY" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
	log_debug_stderr "jq dependency check passed"

	# Add more dependency checks as needed
}

validate_args() {
	log_debug_stderr "Validating required arguments"
	if [ -z "$EXAMPLE_ARG" ]; then
		log_error_stderr "Missing required argument: example argument not specified"
		local msg="Error: example argument must be specified with -x/--example"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "Use -x/--example" "MISSING_ARGUMENTS" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "Use -x/--example" "MISSING_ARGUMENTS" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
	log_debug_stderr "All required arguments are present"
}

# Function to initialize logging based on environment and arguments
init_script_logging() {
	local debug_level="$1"
	local log_file="$2"

	# Determine the effective debug level
	local effective_level=""

	# Build logger initialization arguments
	local logger_args=()

	if [ "${ACTIONS_STEP_DEBUG:-false}" = "true" ]; then
		# GitHub Actions debug mode takes precedence
		effective_level="${debug_level:-DEBUG}"
		logger_args+=(--level "$effective_level")

		# Add log file if specified
		if [ -n "$log_file" ]; then
			logger_args+=(--log "$log_file")
		fi

		# Initialize logger first, then log
		init_logger "${logger_args[@]}"
		log_info_stderr "GitHub Actions step debug mode detected"
		log_debug_stderr "Debug mode enabled with level: $effective_level"
		if [ -n "$log_file" ]; then
			log_info_stderr "Logging to file: $log_file"
		fi
	elif [ -n "$debug_level" ]; then
		# Manual debug flag provided
		effective_level="$debug_level"
		logger_args+=(--level "$effective_level")

		# Add log file if specified
		if [ -n "$log_file" ]; then
			logger_args+=(--log "$log_file")
		fi

		# Initialize logger first, then log
		init_logger "${logger_args[@]}"
		log_debug_stderr "Debug mode enabled with level: $effective_level"
		if [ -n "$log_file" ]; then
			log_info_stderr "Logging to file: $log_file"
		fi
	else
		# Default level
		effective_level="INFO"
		logger_args+=(--level "$effective_level")

		# Add log file if specified
		if [ -n "$log_file" ]; then
			logger_args+=(--log "$log_file")
		fi

		init_logger "${logger_args[@]}"
		if [ -n "$log_file" ]; then
			log_info_stderr "Logging to file: $log_file"
		fi
	fi

	log_debug_stderr "Logger initialized with level: $effective_level"
}

MAIN_LOGIC() {
	log_info_stderr "Executing main script logic"
	log_debug_stderr "Processing example argument: '$EXAMPLE_ARG'"

	# Replace this with your main script logic
	local RESULT_JSON='{"result":"success"}'
	local SUCCESS_STATUS="OK"
	local message="Operation completed successfully."
	local detail="$RESULT_JSON"

	log_debug_stderr "Preparing output in requested format"
	if [ "$JSON_OUTPUT" = true ]; then
		log_debug_stderr "Outputting structured JSON format"
		print_standard_json "$SUCCESS_STATUS" "$message" "$detail"
	else
		log_debug_stderr "Outputting human-readable format"
		print_standard_block "$SUCCESS_STATUS" "$message" "$detail"
	fi

	log_info_stderr "Main logic completed successfully"
}

main() {
	if [ $# -eq 0 ]; then
		show_usage
		exit 1
	fi

	# Parse arguments first to check for debug flag
	parse_args "$@"

	# Initialize logging based on debug flag and log file
	init_script_logging "$DEBUG_LEVEL" "$LOG_FILE"

	log_debug_stderr "Starting script with arguments: $*"
	log_info_stderr "Parsed arguments - Example: '$EXAMPLE_ARG', JSON output: $JSON_OUTPUT, Debug level: ${DEBUG_LEVEL:-NONE}, Log file: ${LOG_FILE:-NONE}"

	validate_args
	log_debug_stderr "Argument validation completed successfully"

	check_dependencies
	log_debug_stderr "Dependency checks completed successfully"

	MAIN_LOGIC
	log_debug_stderr "Script execution completed successfully"
}

main "$@"
