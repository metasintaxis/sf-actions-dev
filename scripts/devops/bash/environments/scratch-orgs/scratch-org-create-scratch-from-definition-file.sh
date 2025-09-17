#!/bin/bash

# -----------------------------------------------------------------------------
# @file scratch-org-create-scratch-from-definition-file.sh
# @brief Create a Salesforce scratch org from a definition file.
#
# This script creates a Salesforce scratch org using a specified definition file,
# duration, Dev Hub alias, and optional namespace. It supports JSON error output.
#
# @usage
#   ./scratch-org-create-scratch-from-definition-file.sh -f <definition-file> -a <alias> -y <duration-days> -v <dev-hub-alias> [-m] [--json] [--log FILE] [--debug [LEVEL]]
#   ./scratch-org-create-scratch-from-definition-file.sh --definition-file <definition-file> --alias <alias> --duration-days <duration-days> --target-dev-hub <dev-hub-alias> [--no-namespace] [--json] [--log FILE] [--debug [LEVEL]]
#
# @options
#   -f, --definition-file    Path to the scratch org definition file.
#   -a, --alias              Alias for the new scratch org.
#   -y, --duration-days      Duration in days for the scratch org.
#   -v, --target-dev-hub     Alias for the Dev Hub org to use for scratch org creation.
#   -m, --no-namespace       Do not use a namespace.
#   --json                   Output result and errors in JSON format.
#   --log FILE               Write debug and operational logs to specified file
#   --debug [LEVEL]          Enable debug logging to stderr. Optional LEVEL:
#                            DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY
#                            (default: DEBUG if no level specified)
#   --help                   Show this help message and exit.
#
# @example
#   ./scratch-org-create-scratch-from-definition-file.sh -d config/scratch-orgs/dev-def.json -a my-scratch -t 30 -h DevHub -n --json
#
# @exitcodes
#   0  Success
#   1  Missing required arguments or invalid usage
# -----------------------------------------------------------------------------

set -euo pipefail

# Get the directory of the current script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../lib/output-utils.sh"
source "${SCRIPT_DIR}/../../lib/logging/watts/logging.sh"

# Global variables for script parameters
DEFINITION_FILE=""
SCRATCH_ALIAS=""
DURATION_DAYS=""
SF_DEV_HUB_ALIAS=""
JSON_OUTPUT=false
NO_NAMESPACE=false
DEBUG_LEVEL=""
LOG_FILE="" # Add this line

show_usage() {
	echo "Usage:"
	echo "  $0 -f <definition-file> -a <alias> -y <duration-days> -v <dev-hub-alias> [-m] [--json] [--log FILE] [--debug [LEVEL]]"
	echo "  $0 --definition-file <definition-file> --alias <alias> --duration-days <duration-days> --target-dev-hub <dev-hub-alias> [--no-namespace] [--json] [--log FILE] [--debug [LEVEL]]"
	echo
	echo "Options:"
	echo "  -f, --definition-file     Path to the scratch org definition file."
	echo "  -a, --alias              Alias for the new scratch org."
	echo "  -y, --duration-days      Duration in days for the scratch org."
	echo "  -v, --target-dev-hub     Alias for the Dev Hub org to use for scratch org creation."
	echo "  -m, --no-namespace       Do not use a namespace."
	echo "  --json                   Output result and errors in JSON format."
	echo "  --log FILE               Write debug and operational logs to specified file"
	echo "  --debug [LEVEL]          Enable debug logging to stderr. Optional LEVEL:"
	echo "                           DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY"
	echo "                           (default: DEBUG if no level specified)"
	echo "  --help                   Show this help message and exit."
}

parse_args() {
	JSON_OUTPUT=false
	NO_NAMESPACE=false
	DEBUG_LEVEL=""
	LOG_FILE="" # Add this line

	while [[ $# -gt 0 ]]; do
		case "$1" in
			-f | --definition-file)
				DEFINITION_FILE="$2"
				shift 2
				;;
			-a | --alias)
				SCRATCH_ALIAS="$2"
				shift 2
				;;
			-y | --duration-days)
				DURATION_DAYS="$2"
				shift 2
				;;
			-v | --target-dev-hub)
				SF_DEV_HUB_ALIAS="$2"
				shift 2
				;;
			-m | --no-namespace)
				NO_NAMESPACE=true
				shift
				;;
			--json)
				JSON_OUTPUT=true
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
			--help)
				show_usage
				exit 0
				;;
			*)
				show_usage
				exit 1
				;;
		esac
	done

	echo "$DEFINITION_FILE|$SCRATCH_ALIAS|$DURATION_DAYS|$SF_DEV_HUB_ALIAS|$NO_NAMESPACE|$JSON_OUTPUT|$DEBUG_LEVEL|$LOG_FILE" # Add LOG_FILE
}

validate_args() {
	local DEFINITION_FILE="$1"
	local SCRATCH_ALIAS="$2"
	local DURATION_DAYS="$3"
	local SF_DEV_HUB_ALIAS="$4"
	local JSON_OUTPUT="$5"

	log_debug_stderr "Validating required arguments"
	if [ -z "$DEFINITION_FILE" ] || [ -z "$SCRATCH_ALIAS" ] || [ -z "$DURATION_DAYS" ] || [ -z "$SF_DEV_HUB_ALIAS" ]; then
		log_error_stderr "Missing required arguments: definition file, alias, duration days, or dev hub alias not specified"
		local msg="Error: definition file, alias, duration days, and dev hub alias must be specified"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "Use -f/--definition-file, -a/--alias, -y/--duration-days, and -v/--target-dev-hub" "MISSING_ARGUMENTS" "${BASH_LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "Use -f/--definition-file, -a/--alias, -y/--duration-days, and -v/--target-dev-hub" "MISSING_ARGUMENTS" "${BASH_LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
	log_debug_stderr "All required arguments are present"
}

check_dependencies() {
	local JSON_OUTPUT="$1"

	log_debug_stderr "Checking script dependencies"

	if ! command -v sf > /dev/null 2>&1; then
		log_error_stderr "Missing dependency: Salesforce CLI (sf) is not installed"
		local msg="Error: Salesforce CLI (sf) is not installed."
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "Install Salesforce CLI to continue." "MISSING_DEPENDENCY" "${BASH_LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "Install Salesforce CLI to continue." "MISSING_DEPENDENCY" "${BASH_LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
	log_debug_stderr "Salesforce CLI dependency check passed"

	if ! command -v jq > /dev/null 2>&1; then
		log_error_stderr "Missing dependency: jq is not installed"
		local msg="Error: jq is required but not installed."
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "Install jq to continue." "MISSING_DEPENDENCY" "${BASH_LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "Install jq to continue." "MISSING_DEPENDENCY" "${BASH_LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
	log_debug_stderr "jq dependency check passed"
}

run_sf_create_scratch_command() {
	local DEFINITION_FILE="$1"
	local SCRATCH_ALIAS="$2"
	local DURATION_DAYS="$3"
	local SF_DEV_HUB_ALIAS="$4"
	local NO_NAMESPACE="$5"
	sf org create scratch \
		--definition-file "$DEFINITION_FILE" \
		--alias "$SCRATCH_ALIAS" \
		--duration-days "$DURATION_DAYS" \
		--target-dev-hub "$SF_DEV_HUB_ALIAS" \
		${NO_NAMESPACE:+--no-namespace} \
		--set-default \
		--async \
		--json
}

start_scratch_org_creation() {
	local DEFINITION_FILE="$1"
	local SCRATCH_ALIAS="$2"
	local DURATION_DAYS="$3"
	local SF_DEV_HUB_ALIAS="$4"
	local NO_NAMESPACE="$5"
	local JSON_OUTPUT="$6"

	log_info_stderr "Starting scratch org creation with alias: '$SCRATCH_ALIAS'"
	log_debug_stderr "Executing sf org create scratch command"

	local CREATE_OUTPUT
	CREATE_OUTPUT=$(run_sf_create_scratch_command "$DEFINITION_FILE" "$SCRATCH_ALIAS" "$DURATION_DAYS" "$SF_DEV_HUB_ALIAS" "$NO_NAMESPACE")
	local status=$?

	if [ $status -ne 0 ] || echo "$CREATE_OUTPUT" | jq -e '.status // empty' | grep -q 1; then
		log_error_stderr "sf org create scratch command failed"
		local msg="Error: Failed to start scratch org creation."
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$CREATE_OUTPUT" "SCRATCH_ORG_CREATION_FAILED" "${BASH_LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$CREATE_OUTPUT" "SCRATCH_ORG_CREATION_FAILED" "${BASH_LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		fi
		return 0
	fi

	log_debug_stderr "Scratch org creation command executed successfully"
	echo "$CREATE_OUTPUT"
}

get_job_id() {
	local create_output="$1"
	echo "$create_output" | jq -r '.result.scratchOrgInfo.Id // empty'
}

check_job_id() {
	local job_id="$1"
	local create_output="$2"
	local json_output="$3"

	log_debug_stderr "Validating extracted job ID: '$job_id'"

	if [ -z "$job_id" ] || [ "$job_id" = "null" ]; then
		log_error_stderr "Could not extract valid job ID from scratch org creation output"
		local msg="Error: Could not extract job ID from scratch org creation output."
		local func="${FUNCNAME[0]}"
		if [ "$json_output" = true ]; then
			print_error_json "$msg" "$create_output" "NO_JOB_ID" "${LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$create_output" "NO_JOB_ID" "${LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi

	log_debug_stderr "Job ID validation passed"
}

show_progress() {
	local JOB_ID="$1"
	echo "Scratch org creation started. Job ID: $JOB_ID" >&2
	echo "Showing progress (human readable):" >&2
	sf org resume scratch --job-id "$JOB_ID" --wait 30 >&2
}

get_final_json_output() {
	local JOB_ID="$1"
	local CREATE_OUTPUT="$2"
	local JSON_OUTPUT="$3"

	log_debug_stderr "Retrieving final scratch org creation status"

	local FINAL_JSON
	if ! FINAL_JSON=$(sf org resume scratch --job-id "$JOB_ID" --json 2> /dev/null); then
		log_warn "sf org resume scratch command failed, attempting to use CREATE_OUTPUT"
		# If resume fails, try to use CREATE_OUTPUT if it's valid JSON
		if echo "$CREATE_OUTPUT" | jq empty 2> /dev/null; then
			FINAL_JSON="$CREATE_OUTPUT"
			log_debug_stderr "Using CREATE_OUTPUT as fallback for final result"
		else
			log_error_stderr "Neither resume nor CREATE_OUTPUT returned valid JSON"
			local msg="Neither resume nor CREATE_OUTPUT returned valid JSON."
			local func="${FUNCNAME[0]}"
			if [ "$JSON_OUTPUT" = true ]; then
				print_error_json "$msg" "$CREATE_OUTPUT" "INVALID_JSON" "${BASH_LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
			else
				print_error_block "$msg" "$CREATE_OUTPUT" "INVALID_JSON" "${BASH_LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
			fi
			exit 1
		fi
	else
		log_debug_stderr "Successfully retrieved final scratch org status"
	fi

	echo "$FINAL_JSON"
}

output_final_result() {
	local FINAL_JSON="$1"
	local JSON_OUTPUT="$2"

	log_debug_stderr "Preparing final output in requested format"

	if [ "$JSON_OUTPUT" = true ]; then
		log_debug_stderr "Outputting structured JSON format"
		print_standard_json "OK" "Scratch org created successfully." "$FINAL_JSON"
	else
		log_debug_stderr "Outputting human-readable format"
		print_standard_block "OK" "Scratch org created successfully!" "$FINAL_JSON"
	fi

	log_debug_stderr "Output formatting completed"
}

run_scratch_org_creation() {
	local DEFINITION_FILE="$1"
	local SCRATCH_ALIAS="$2"
	local DURATION_DAYS="$3"
	local SF_DEV_HUB_ALIAS="$4"
	local NO_NAMESPACE="$5"
	local JSON_OUTPUT="$6"

	local CREATE_OUTPUT JOB_ID FINAL_JSON

	CREATE_OUTPUT=$(start_scratch_org_creation "$DEFINITION_FILE" "$SCRATCH_ALIAS" "$DURATION_DAYS" "$SF_DEV_HUB_ALIAS" "$NO_NAMESPACE" "$JSON_OUTPUT")
	# Check for error indicators in the output
	if echo "$CREATE_OUTPUT" | grep -q -e 'Status    : ERROR' -e '"status": "ERROR"'; then
		echo "$CREATE_OUTPUT"
		exit 0
	fi

	# Extract job ID using dedicated extraction function
	JOB_ID=$(get_job_id "$CREATE_OUTPUT")
	# Validate the extracted job ID using separate validation function
	check_job_id "$JOB_ID" "$CREATE_OUTPUT" "$JSON_OUTPUT"
	show_progress "$JOB_ID"
	FINAL_JSON=$(get_final_json_output "$JOB_ID" "$CREATE_OUTPUT" "$JSON_OUTPUT")
	output_final_result "$FINAL_JSON" "$JSON_OUTPUT"
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
	if [ $# -eq 0 ]; then
		show_usage
		exit 1
	fi

	local parsed
	parsed=$(parse_args "$@")
	IFS='|' read -r DEFINITION_FILE SCRATCH_ALIAS DURATION_DAYS SF_DEV_HUB_ALIAS NO_NAMESPACE JSON_OUTPUT DEBUG_LEVEL LOG_FILE <<< "$parsed" # Add LOG_FILE

	# Initialize logging based on debug flag and log file
	init_script_logging "$DEBUG_LEVEL" "$LOG_FILE"

	log_debug_stderr "Starting scratch-org-create-scratch-from-definition-file.sh with arguments: $*"
	log_info_stderr "Parsed arguments - Definition file: '$DEFINITION_FILE', Alias: '$SCRATCH_ALIAS', Duration: $DURATION_DAYS days, Dev Hub: '$SF_DEV_HUB_ALIAS', No namespace: $NO_NAMESPACE, JSON output: $JSON_OUTPUT, Debug level: ${DEBUG_LEVEL:-NONE}, Log file: ${LOG_FILE:-NONE}"

	validate_args "$DEFINITION_FILE" "$SCRATCH_ALIAS" "$DURATION_DAYS" "$SF_DEV_HUB_ALIAS" "$JSON_OUTPUT"
	log_debug_stderr "Argument validation completed successfully"

	check_dependencies "$JSON_OUTPUT"
	log_debug_stderr "Dependency checks completed successfully"

	run_scratch_org_creation "$DEFINITION_FILE" "$SCRATCH_ALIAS" "$DURATION_DAYS" "$SF_DEV_HUB_ALIAS" "$NO_NAMESPACE" "$JSON_OUTPUT"
	log_info_stderr "Scratch org creation process completed successfully"
	log_debug_stderr "Script execution completed successfully"
}

main "$@"
