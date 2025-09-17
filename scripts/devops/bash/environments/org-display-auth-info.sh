#!/bin/bash

# -----------------------------------------------------------------------------
# @file org-display-auth-info.sh
# @brief Display Salesforce org authentication information in JSON or human-readable format.
#
# This script retrieves authentication details for a specified Salesforce org
# using the Salesforce CLI and outputs the result to stdout.
#
# @usage
#   ./org-display-auth-info.sh -o <target-org> [--json]
#   ./org-display-auth-info.sh --target-org <target-org> [--json]
#   ./org-display-auth-info.sh -o <target-org> --sfdx-auth-url-condensed
#
# @options
#   -o, --target-org                The alias or username of the target Salesforce org.
#   -h, --help                      Show this help message and exit.
#   --json                          Output result and errors in JSON format.
#   --sfdx-auth-url-condensed       Output only the raw JSON from sf in a single line.
#   --debug [LEVEL]                 Enable debug logging to stderr. Optional LEVEL:
#                                  DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY
#                                  (default: DEBUG if no level specified)
#
# @example
#   ./org-display-auth-info.sh -o my-org --json
#   ./org-display-auth-info.sh -o my-org --sfdx-auth-url-condensed
#
# @exitcodes
#   0  Success
#   1  Missing required arguments or invalid usage
# -----------------------------------------------------------------------------

set -euo pipefail

# Get the directory of the current script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/output-utils.sh"
source "${SCRIPT_DIR}/../lib/logging/watts/logging.sh"

TARGET_ORG=""
JSON_OUTPUT=false
SFDX_AUTH_URL_CONDENSED=false
DEBUG_LEVEL=""
LOG_FILE="" # Add this line

show_usage() {
	echo "Usage:"
	echo "  $0 -o <target-org> [--json] [--log FILE] [--debug [LEVEL]]"
	echo "  $0 --target-org <target-org> [--json] [--log FILE] [--debug [LEVEL]]"
	echo "  $0 -o <target-org> --sfdx-auth-url-condensed [--log FILE] [--debug [LEVEL]]"
	echo
	echo "Options:"
	echo "  -o, --target-org                The alias or username of the target Salesforce org."
	echo "  -h, --help                      Show this help message and exit."
	echo "  --json                          Output result and errors in JSON format."
	echo "  --sfdx-auth-url-condensed       Output only the raw JSON from sf in a single line."
	echo "  --log FILE                      Write debug and operational logs to specified file"
	echo "  --debug [LEVEL]                 Enable debug logging to stderr. Optional LEVEL:"
	echo "                                  DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY"
	echo "                                  (default: DEBUG if no level specified)"
}

parse_args() {
	JSON_OUTPUT=false
	SFDX_AUTH_URL_CONDENSED=false
	DEBUG_LEVEL=""
	LOG_FILE="" # Add this line

	while [[ $# -gt 0 ]]; do
		case "$1" in
			-o | --target-org)
				TARGET_ORG="$2"
				shift 2
				;;
			--json)
				JSON_OUTPUT=true
				shift
				;;
			--sfdx-auth-url-condensed)
				SFDX_AUTH_URL_CONDENSED=true
				shift
				;;
			--log) # Add this case
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

	if ! command -v sf > /dev/null 2>&1; then
		log_error_stderr "Missing dependency: Salesforce CLI (sf) is not installed"
		local msg="Error: Salesforce CLI (sf) is not installed."
		local detail="Install Salesforce CLI to continue."
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "MISSING_DEPENDENCY" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "MISSING_DEPENDENCY" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
	log_debug_stderr "Salesforce CLI dependency check passed"
}

validate_args() {
	log_debug_stderr "Validating required arguments"
	if [ -z "$TARGET_ORG" ]; then
		log_error_stderr "Missing required argument: target org not specified"
		local msg="Error: target org must be specified with -o/--target-org"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "Use -o/--target-org" "MISSING_ARGUMENTS" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "Use -o/--target-org" "MISSING_ARGUMENTS" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
	log_debug_stderr "All required arguments are present"
}

run_sf_command() {
	log_info_stderr "Executing sf org display command for org: '$TARGET_ORG'"
	log_debug_stderr "Running: sf org display --target-org '$TARGET_ORG' --verbose --json"

	if ! FINAL_JSON=$(sf org display --target-org "$TARGET_ORG" --verbose --json 2> /dev/null); then
		log_error_stderr "sf org display command failed for org: '$TARGET_ORG'"
		local msg="Failed to retrieve org authentication information for '$TARGET_ORG'."
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$FINAL_JSON" "ORG_DISPLAY_FAILED" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$FINAL_JSON" "ORG_DISPLAY_FAILED" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi

	log_debug_stderr "sf command executed successfully, response length: ${#FINAL_JSON} characters"
}

output_final_result() {
	log_debug_stderr "Preparing output in requested format"

	local SUCCESS_STATUS="OK"
	local message="Org authentication information retrieved successfully."
	local detail="$FINAL_JSON"

	if [ "$SFDX_AUTH_URL_CONDENSED" = true ]; then
		log_debug_stderr "Outputting condensed JSON format"
		echo "$FINAL_JSON" | jq -c .
	elif [ "$JSON_OUTPUT" = true ]; then
		log_debug_stderr "Outputting structured JSON format"
		print_standard_json "$SUCCESS_STATUS" "$message" "$detail"
	else
		log_debug_stderr "Outputting human-readable format"
		print_standard_block "$SUCCESS_STATUS" "$message" "$detail"
	fi

	log_debug_stderr "Output formatting completed"
}

check_no_args() {
	if [ $# -eq 0 ]; then
		show_usage
		exit 1
	fi
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

main() {
	# Parse arguments first to check for debug flag
	parse_args "$@"

	# Initialize logging based on debug flag and log file
	init_script_logging "$DEBUG_LEVEL" "$LOG_FILE"

	log_debug_stderr "Starting org-display-auth-info.sh with arguments: $*"

	check_no_args "$@"
	log_debug_stderr "Arguments validation passed"

	log_info_stderr "Parsed arguments - Target org: '$TARGET_ORG', JSON output: $JSON_OUTPUT, Condensed: $SFDX_AUTH_URL_CONDENSED, Debug level: ${DEBUG_LEVEL:-NONE}, Log file: ${LOG_FILE:-NONE}"

	validate_args
	log_debug_stderr "Argument validation completed successfully"

	check_dependencies
	log_debug_stderr "Dependency checks completed successfully"

	run_sf_command
	log_info_stderr "Successfully retrieved org information for '$TARGET_ORG'"

	output_final_result
	log_debug_stderr "Script execution completed successfully"
}

main "$@"
