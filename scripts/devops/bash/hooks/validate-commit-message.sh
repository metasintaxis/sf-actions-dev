#!/bin/bash

# -----------------------------------------------------------------------------
# @file validate-commit-message.sh
# @brief Validate commit message format against GitHub issue convention
#
# @description
#   Git hook script that validates commit messages follow the required format:
#   GH-XXXX: Message. Automatically skips validation for merge commits and
#   provides detailed error messages with examples when validation fails.
#   Used as a commit-msg Git hook to enforce commit message conventions.
#
# @usage
#   ./validate-commit-message.sh <commit-msg-file> [--json] [--log FILE] [--debug [LEVEL]]
#   git commit -m "GH-123: Add feature"  # Validates message format
#
# @options
#   --json                Output result and errors in JSON format.
#   --log FILE            Write debug and operational logs to specified file
#   --debug [LEVEL]       Enable debug logging to stderr. Optional LEVEL:
#                         DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY
#                         (default: DEBUG if no level specified)
#   -h, --help            Show this help message and exit.
#
# @exitcodes
#   0  Success (message is valid or legitimately skipped)
#   1  Invalid usage, missing arguments, or validation failure
# -----------------------------------------------------------------------------

set -euo pipefail

# Get the directory of the current script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/output-utils.sh"
source "${SCRIPT_DIR}/../lib/logging/watts/logging.sh"

# Default values for arguments
COMMIT_MSG_FILE=""
JSON_OUTPUT=false
DEBUG_LEVEL=""
LOG_FILE=""

show_usage() {
	echo "Usage:"
	echo "  $0 <commit-msg-file> [--json] [--log FILE] [--debug [LEVEL]]"
	echo
	echo "Arguments:"
	echo "  commit-msg-file       Path to the commit message file"
	echo
	echo "Options:"
	echo "  --json                Output result and errors in JSON format."
	echo "  --log FILE            Write debug and operational logs to specified file"
	echo "  --debug [LEVEL]       Enable debug logging to stderr. Optional LEVEL:"
	echo "                        DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY"
	echo "                        (default: DEBUG if no level specified)"
	echo "  -h, --help            Show this help message and exit."
}

parse_args() {
	COMMIT_MSG_FILE=""
	JSON_OUTPUT=false
	DEBUG_LEVEL=""
	LOG_FILE=""

	local positional_args=()

	while [[ $# -gt 0 ]]; do
		case "$1" in
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
			-*)
				show_usage >&2
				exit 1
				;;
			*)
				positional_args+=("$1")
				shift
				;;
		esac
	done

	# Set positional arguments
	if [[ ${#positional_args[@]} -ge 1 ]]; then
		COMMIT_MSG_FILE="${positional_args[0]}"
	fi
}

check_dependencies() {
	log_debug_stderr "Checking script dependencies"

	# Check for git (usually available in Git hook context, but validate anyway)
	if ! command -v git > /dev/null 2>&1; then
		log_error_stderr "Missing dependency: git is not installed"
		local msg="Error: git is required but not installed."
		local detail="Install git to continue."
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "MISSING_DEPENDENCY" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "MISSING_DEPENDENCY" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
	log_debug_stderr "git dependency check passed"
}

validate_args() {
	log_debug_stderr "Validating required arguments"
	if [ -z "$COMMIT_MSG_FILE" ]; then
		log_error_stderr "Missing required argument: commit message file not specified"
		local msg="Error: commit message file must be specified as first argument"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "Provide path to commit message file" "MISSING_ARGUMENTS" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "Provide path to commit message file" "MISSING_ARGUMENTS" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
	
	if [ ! -f "$COMMIT_MSG_FILE" ]; then
		log_error_stderr "Commit message file does not exist: $COMMIT_MSG_FILE"
		local msg="Error: commit message file not found"
		local detail="File: $COMMIT_MSG_FILE"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "FILE_NOT_FOUND" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "FILE_NOT_FOUND" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
	
	log_debug_stderr "All required arguments are present and valid"
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

# Pure function to extract first line of commit message
get_commit_message_first_line() {
	local commit_msg_file="$1"
	head -n 1 "$commit_msg_file" 2>/dev/null || echo ""
}

# Pure function to check if message is a merge commit
is_merge_commit() {
	local commit_msg="$1"
	[[ $commit_msg =~ ^Merge\ (branch|pull\ request) ]]
}

# Pure function to validate commit message format
is_valid_commit_format() {
	local commit_msg="$1"
	local pattern="^GH-[0-9]+: [A-Za-z].{1,}$"
	[[ $commit_msg =~ $pattern ]]
}

# Function to generate validation error details
generate_validation_error_detail() {
	local current_msg="$1"
	
	cat << EOF
Current message: $current_msg

Expected format: GH-XXXX: [Message]

Where:
  GH-XXXX   = GitHub issue number (e.g., GH-80, GH-123; XXXX is any number)
  Message   = Brief description, starts with a letter

Good examples:
  GH-80: Add commit message validation
  GH-123: Add user authentication feature
  GH-456: Fix login timeout issue
  GH-789: Update documentation for API endpoints
  GH-321: Refactor database connection logic
  GH-555: Remove deprecated methods
  GH-888: Implement password reset functionality
  GH-93: bash-devops.instructions.md file added

Bad examples:
  GH80: missing colon and space
  gh-456: lowercase prefix
  GH-789 missing colon
  GH-321: fix bug (too vague)
  Add authentication (missing issue reference)
  Fixed stuff (no issue number and vague)

To use the commit message template:
  git config commit.template .gitmessage
EOF
}

validate_commit_message() {
	log_info_stderr "Starting commit message validation"
	
	# Extract commit message using pure function
	local commit_msg
	commit_msg=$(get_commit_message_first_line "$COMMIT_MSG_FILE")
	log_debug_stderr "Extracted commit message: '$commit_msg'"
	
	# Check if it's a merge commit (skip validation)
	if is_merge_commit "$commit_msg"; then
		log_info_stderr "Merge commit detected, skipping validation"
		local msg="Merge commit detected, validation skipped"
		local detail="Message: '$commit_msg'"
		if [ "$JSON_OUTPUT" = true ]; then
			print_standard_json "OK" "$msg" "$detail"
		else
			print_standard_block "OK" "$msg" "$detail"
		fi
		return 0
	fi
	
	# Validate commit message format
	if is_valid_commit_format "$commit_msg"; then
		log_info_stderr "Commit message format is valid"
		local msg="Commit message format is valid"
		local detail="Message: '$commit_msg'"
		if [ "$JSON_OUTPUT" = true ]; then
			print_standard_json "OK" "$msg" "$detail"
		else
			print_standard_block "OK" "$msg" "$detail"
		fi
		return 0
	else
		log_error_stderr "Invalid commit message format: '$commit_msg'"
		local msg="Invalid commit message format"
		local detail
		detail=$(generate_validation_error_detail "$commit_msg")
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "INVALID_FORMAT" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "INVALID_FORMAT" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
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
	log_info_stderr "Parsed arguments - Commit file: '$COMMIT_MSG_FILE', JSON output: $JSON_OUTPUT, Debug level: ${DEBUG_LEVEL:-NONE}, Log file: ${LOG_FILE:-NONE}"

	validate_args
	log_debug_stderr "Argument validation completed successfully"

	check_dependencies
	log_debug_stderr "Dependency checks completed successfully"

	validate_commit_message
	log_debug_stderr "Script execution completed successfully"
}

main "$@"
