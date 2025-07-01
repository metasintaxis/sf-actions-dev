#!/bin/bash

# -----------------------------------------------------------------------------
# @file delete-flow.sh
# @brief Delete flow versions in Salesforce with a specified status.
#
# @description
#   This script deletes flow versions in Salesforce using the Salesforce CLI.
#   It queries for flow versions with a specified status for a given flow developer name and deletes them.
#
# @usage
#   ./delete-flow.sh -d <developer-name> -s <status> [-o <target-org>] [--json] [--log FILE] [--debug [LEVEL]]
#   ./delete-flow.sh --developer-name <developer-name> --status <status> [--target-org <target-org>] [--json] [--log FILE] [--debug [LEVEL]]
#
# @options
#   -d, --developer-name  The developer name of the flow.
#   -s, --status          The status of the flow versions to delete (e.g., Obsolete, Draft, Active).
#   -o, --target-org      The alias or username of the target Salesforce org (optional).
#   --json                Output result and errors in JSON format.
#   --log FILE            Write debug and operational logs to specified file
#   --debug [LEVEL]       Enable debug logging to stderr. Optional LEVEL:
#                         DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY
#                         (default: DEBUG if no level specified)
#   -h, --help            Show this help message and exit.
#
# @example
#   ./delete-flow.sh -d "TestFlow" -s "Obsolete" -o my-org --json
#   ./delete-flow.sh --developer-name "TestFlow" --status "Draft" --target-org my-org
#
# @exitcodes
#   0  Success
#   1  Missing required arguments, invalid usage, or error during execution
# -----------------------------------------------------------------------------

set -euo pipefail

# Get the directory of the current script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../bash/lib/output-utils.sh"
source "${SCRIPT_DIR}/../../bash/lib/logging/watts/logging.sh"

# Default values for arguments
DEVELOPER_NAME=""
FLOW_STATUS=""
TARGET_ORG=""
JSON_OUTPUT=false
DEBUG_LEVEL=""
LOG_FILE=""

show_usage() {
	echo "Usage:"
	echo "  $0 -d <developer-name> -s <status> [-o <target-org>] [--json] [--log FILE] [--debug [LEVEL]]"
	echo "  $0 --developer-name <developer-name> --status <status> [--target-org <target-org>] [--json] [--log FILE] [--debug [LEVEL]]"
	echo
	echo "Options:"
	echo "  -d, --developer-name  The developer name of the flow."
	echo "  -s, --status          The status of the flow versions to delete (e.g., Obsolete, Draft, Active)."
	echo "  -o, --target-org      The alias or username of the target Salesforce org (optional)."
	echo "  --json                Output result and errors in JSON format."
	echo "  --log FILE            Write debug and operational logs to specified file"
	echo "  --debug [LEVEL]       Enable debug logging to stderr. Optional LEVEL:"
	echo "                        DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY"
	echo "                        (default: DEBUG if no level specified)"
	echo "  -h, --help            Show this help message and exit."
}

parse_args() {
	DEVELOPER_NAME=""
	FLOW_STATUS=""
	TARGET_ORG=""
	JSON_OUTPUT=false
	DEBUG_LEVEL=""
	LOG_FILE=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
			-d | --developer-name)
				DEVELOPER_NAME="$2"
				shift 2
				;;
			-s | --status)
				FLOW_STATUS="$2"
				shift 2
				;;
			-o | --target-org)
				TARGET_ORG="$2"
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
	if [ -z "$DEVELOPER_NAME" ]; then
		log_error_stderr "Missing required argument: developer name not specified"
		local msg="Error: developer name must be specified with -d/--developer-name"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "Use -d/--developer-name" "MISSING_ARGUMENTS" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "Use -d/--developer-name" "MISSING_ARGUMENTS" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi

	if [ -z "$FLOW_STATUS" ]; then
		log_error_stderr "Missing required argument: flow status not specified"
		local msg="Error: flow status must be specified with -s/--status"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "Use -s/--status (e.g., Obsolete, Draft, Active)" "MISSING_ARGUMENTS" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "Use -s/--status (e.g., Obsolete, Draft, Active)" "MISSING_ARGUMENTS" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi

	# Validate flow status is one of the expected values
	case "$FLOW_STATUS" in
		"Active"|"Draft"|"Obsolete"|"InvalidDraft")
			log_debug_stderr "Flow status validation passed: '$FLOW_STATUS'"
			;;
		*)
			log_warn_stderr "Warning: Unusual flow status specified: '$FLOW_STATUS'. Common values are: Active, Draft, Obsolete, InvalidDraft"
			;;
	esac

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

query_obsolete_flows() {
	log_info_stderr "Querying for flow versions with status '$FLOW_STATUS'"
	log_debug_stderr "Flow: '$DEVELOPER_NAME', Status: '$FLOW_STATUS', Target org: '${TARGET_ORG:-default}'"

	# Construct the SOQL query to find flow versions with specified status
	local QUERY="SELECT Id, VersionNumber, MasterLabel, Definition.DeveloperName FROM Flow WHERE Status = '$FLOW_STATUS' AND Definition.DeveloperName = '$DEVELOPER_NAME' ORDER BY VersionNumber DESC"
	log_debug_stderr "SOQL Query: $QUERY"

	# Build sf command with optional target org
	local SF_COMMAND="sf data query --use-tooling-api --query \"$QUERY\" --result-format json"
	if [ -n "$TARGET_ORG" ]; then
		SF_COMMAND="$SF_COMMAND --target-org \"$TARGET_ORG\""
	fi

	log_debug_stderr "Executing: $SF_COMMAND"

	local QUERY_RESULT
	if ! QUERY_RESULT=$(eval "$SF_COMMAND" 2>/dev/null); then
		log_error_stderr "Failed to query for flow versions with status '$FLOW_STATUS'"
		local msg="Failed to query for flow versions with status '$FLOW_STATUS' for flow '$DEVELOPER_NAME'"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$QUERY_RESULT" "QUERY_FAILED" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$QUERY_RESULT" "QUERY_FAILED" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi

	log_debug_stderr "Query executed successfully"
	echo "$QUERY_RESULT"
}

delete_flow_versions() {
	local QUERY_RESULT="$1"
	
	log_debug_stderr "Processing query results for deletion"

	# Extract records from the query result
	local RECORDS
	RECORDS=$(echo "$QUERY_RESULT" | jq -r '.result.records[]? | "\(.Id),\(.VersionNumber)"')

	if [ -z "$RECORDS" ]; then
		log_info_stderr "No flow versions found to delete with status '$FLOW_STATUS'"
		local msg="No flow versions found for flow '$DEVELOPER_NAME' with status '$FLOW_STATUS'"
		local detail='{"deletedRecords": 0, "records": []}'
		if [ "$JSON_OUTPUT" = true ]; then
			print_standard_json "OK" "$msg" "$detail"
		else
			print_standard_block "OK" "$msg" "$detail"
		fi
		return 0
	fi

	log_info_stderr "Found flow versions to delete:"
	
	local DELETED_RECORDS=()
	local DELETE_COUNT=0

	# Process each record
	while IFS=',' read -r flow_id version_number; do
		if [ -n "$flow_id" ] && [ "$flow_id" != "null" ]; then
			log_info_stderr "Deleting flow version $version_number (ID: $flow_id)"
			
			# Build delete command with optional target org
			local DELETE_COMMAND="sf data delete record --use-tooling-api --sobject Flow --record-id \"$flow_id\""
			if [ -n "$TARGET_ORG" ]; then
				DELETE_COMMAND="$DELETE_COMMAND --target-org \"$TARGET_ORG\""
			fi

			log_debug_stderr "Executing: $DELETE_COMMAND"

			if eval "$DELETE_COMMAND" >/dev/null 2>&1; then
				log_info_stderr "Successfully deleted flow version $version_number"
				DELETED_RECORDS+=("{\"id\": \"$flow_id\", \"versionNumber\": $version_number}")
				((DELETE_COUNT++))
			else
				log_error_stderr "Failed to delete flow version $version_number (ID: $flow_id)"
				local msg="Failed to delete flow version $version_number"
				local detail="Flow ID: $flow_id"
				local func="${FUNCNAME[0]}"
				if [ "$JSON_OUTPUT" = true ]; then
					print_error_json "$msg" "$detail" "DELETE_FAILED" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
				else
					print_error_block "$msg" "$detail" "DELETE_FAILED" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
				fi
				exit 1
			fi
		fi
	done <<< "$RECORDS"

	log_info_stderr "Successfully deleted $DELETE_COUNT flow versions with status '$FLOW_STATUS'"

	# Prepare result JSON
	local DELETED_RECORDS_JSON
	if [ ${#DELETED_RECORDS[@]} -eq 0 ]; then
		DELETED_RECORDS_JSON="[]"
	else
		DELETED_RECORDS_JSON="[$(IFS=','; echo "${DELETED_RECORDS[*]}")]"
	fi

	local RESULT_JSON="{\"deletedRecords\": $DELETE_COUNT, \"records\": $DELETED_RECORDS_JSON}"
	local SUCCESS_STATUS="OK"
	local message="Successfully deleted $DELETE_COUNT flow versions with status '$FLOW_STATUS' for flow '$DEVELOPER_NAME'"

	log_debug_stderr "Preparing output in requested format"
	if [ "$JSON_OUTPUT" = true ]; then
		log_debug_stderr "Outputting structured JSON format"
		print_standard_json "$SUCCESS_STATUS" "$message" "$RESULT_JSON"
	else
		log_debug_stderr "Outputting human-readable format"
		print_standard_block "$SUCCESS_STATUS" "$message" "$RESULT_JSON"
	fi
}

delete_flow() {
	log_info_stderr "Executing flow deletion logic"
	log_debug_stderr "Processing flow: '$DEVELOPER_NAME', status: '$FLOW_STATUS'"

	local QUERY_RESULT
	QUERY_RESULT=$(query_obsolete_flows)
	
	delete_flow_versions "$QUERY_RESULT"
	
	log_info_stderr "Flow deletion process completed successfully"
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
	log_info_stderr "Parsed arguments - Developer name: '$DEVELOPER_NAME', Status: '$FLOW_STATUS', Target org: '${TARGET_ORG:-default}', JSON output: $JSON_OUTPUT, Debug level: ${DEBUG_LEVEL:-NONE}, Log file: ${LOG_FILE:-NONE}"

	validate_args
	log_debug_stderr "Argument validation completed successfully"

	check_dependencies
	log_debug_stderr "Dependency checks completed successfully"

	delete_flow
	log_debug_stderr "Script execution completed successfully"
}

main "$@"
