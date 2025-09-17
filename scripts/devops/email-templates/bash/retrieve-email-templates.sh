#!/bin/bash

# -----------------------------------------------------------------------------
# @file scripts/email-templates/bash/retrieve-email-templates.sh
# @brief Retrieve email templates from a specified template folder
#
# @description
#   This script retrieves all email templates from a specified template folder by:
#   1. Querying for all template developer names in the folder
#   2. Iterating over each template and retrieving it using sf project retrieve start
#   The script supports both JSON and human-readable output formats.
#
# @usage
#   ./retrieve-email-templates.sh -f FOLDER_DEVELOPER_NAME [-o TARGET_ORG] [--json] [--log FILE] [--debug [LEVEL]]
#   ./retrieve-email-templates.sh --folder FOLDER_DEVELOPER_NAME [--target-org TARGET_ORG] [--json] [--log FILE] [--debug [LEVEL]]
#
# @options
#   -f, --folder           The DeveloperName of the template folder (required)
#   -o, --target-org       The alias or username of the target Salesforce org (optional, uses default org if not specified)
#   --json                 Output result and errors in JSON format.
#   --log FILE             Write debug and operational logs to specified file
#   --debug [LEVEL]        Enable debug logging to stderr. Optional LEVEL:
#                          DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY
#                          (default: DEBUG if no level specified)
#   -h, --help             Show this help message and exit.
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
FOLDER_DEVELOPER_NAME=""
TARGET_ORG=""
JSON_OUTPUT=false
DEBUG_LEVEL=""
LOG_FILE=""

show_usage() {
	echo "Usage:"
	echo "  $0 -f FOLDER_DEVELOPER_NAME [-o TARGET_ORG] [--json] [--log FILE] [--debug [LEVEL]]"
	echo "  $0 --folder FOLDER_DEVELOPER_NAME [--target-org TARGET_ORG] [--json] [--log FILE] [--debug [LEVEL]]"
	echo
	echo "Options:"
	echo "  -f, --folder           The DeveloperName of the template folder (required)"
	echo "  -o, --target-org       The alias or username of the target Salesforce org (optional, uses default org if not specified)"
	echo "  --json                 Output result and errors in JSON format."
	echo "  --log FILE             Write debug and operational logs to specified file"
	echo "  --debug [LEVEL]        Enable debug logging to stderr. Optional LEVEL:"
	echo "                         DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY"
	echo "                         (default: DEBUG if no level specified)"
	echo "  -h, --help             Show this help message and exit."
}

parse_args() {
	FOLDER_DEVELOPER_NAME=""
	TARGET_ORG=""
	JSON_OUTPUT=false
	DEBUG_LEVEL=""
	LOG_FILE=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
			-f | --folder)
				FOLDER_DEVELOPER_NAME="$2"
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
}

validate_args() {
	log_debug_stderr "Validating required arguments"
	if [ -z "$FOLDER_DEVELOPER_NAME" ]; then
		log_error_stderr "Missing required argument: folder developer name not specified"
		local msg="Error: folder developer name must be specified with -f/--folder"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "Use -f/--folder to specify the template folder" "MISSING_ARGUMENTS" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "Use -f/--folder to specify the template folder" "MISSING_ARGUMENTS" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
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

query_email_templates() {
	local folder_name="$1"
	local target_org_flag=""
	
	if [ -n "$TARGET_ORG" ]; then
		target_org_flag="--target-org $TARGET_ORG"
	fi

	local query="SELECT Id, Name, DeveloperName, FolderName FROM EmailTemplate WHERE Folder.DeveloperName = '$folder_name'"
	
	log_debug_stderr "Executing email templates query: $query"
	sf data query --query "$query" $target_org_flag --json
}

is_sf_error_json() {
	echo "$1" | jq -e 'has("status") and .status == 1' > /dev/null 2>&1
}

retrieve_email_template() {
	local folder_name="$1"
	local template_name="$2"
	local target_org_flag=""
	
	if [ -n "$TARGET_ORG" ]; then
		target_org_flag="--target-org $TARGET_ORG"
	fi

	local metadata_name="EmailTemplate:${folder_name}/${template_name}"
	
	log_debug_stderr "Retrieving email template: $metadata_name"
	sf project retrieve start -m "$metadata_name" $target_org_flag --json
}

retrieve_email_templates() {
	log_info_stderr "Starting email template retrieval process"
	log_debug_stderr "Processing folder: '$FOLDER_DEVELOPER_NAME'"

	# Query for email templates in the specified folder
	local TEMPLATES_JSON
	local query_status=0
	TEMPLATES_JSON=$(query_email_templates "$FOLDER_DEVELOPER_NAME") || query_status=$?

	log_debug_stderr "Templates query completed with status: $query_status"
	if [ $query_status -ne 0 ] || is_sf_error_json "$TEMPLATES_JSON"; then
		log_error_stderr "Failed to query email templates"
		local msg="Failed to query email templates from folder '$FOLDER_DEVELOPER_NAME'"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$TEMPLATES_JSON" "QUERY_TEMPLATES_FAILED" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$TEMPLATES_JSON" "QUERY_TEMPLATES_FAILED" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi

	# Extract template developer names
	local template_count
	template_count=$(echo "$TEMPLATES_JSON" | jq -r '.result.records | length')
	log_info_stderr "Found $template_count email templates in folder '$FOLDER_DEVELOPER_NAME'"

	if [ "$template_count" -eq 0 ]; then
		log_info_stderr "No email templates found in folder '$FOLDER_DEVELOPER_NAME'"
		local msg="No email templates found in folder '$FOLDER_DEVELOPER_NAME'"
		local detail='{"templates_found": 0, "templates_retrieved": 0}'
		if [ "$JSON_OUTPUT" = true ]; then
			print_standard_json "OK" "$msg" "$detail"
		else
			print_standard_block "OK" "$msg" "$detail"
		fi
		return 0
	fi

	# Extract template developer names and iterate over them
	local template_names
	template_names=$(echo "$TEMPLATES_JSON" | jq -r '.result.records[].DeveloperName')
	
	local retrieved_count=0
	local failed_count=0
	local retrieval_results=()

	log_info_stderr "Starting retrieval of individual templates"
	
	while IFS= read -r template_name; do
		if [ -n "$template_name" ]; then
			log_info_stderr "Retrieving template: $template_name"
			
			local RETRIEVE_JSON
			local retrieve_status=0
			RETRIEVE_JSON=$(retrieve_email_template "$FOLDER_DEVELOPER_NAME" "$template_name") || retrieve_status=$?
			
			if [ $retrieve_status -eq 0 ] && ! is_sf_error_json "$RETRIEVE_JSON"; then
				log_info_stderr "Successfully retrieved template: $template_name"
				retrieved_count=$((retrieved_count + 1))
				retrieval_results+=("{\"template\": \"$template_name\", \"status\": \"success\"}")
			else
				log_error_stderr "Failed to retrieve template: $template_name"
				failed_count=$((failed_count + 1))
				retrieval_results+=("{\"template\": \"$template_name\", \"status\": \"failed\", \"error\": $(echo "$RETRIEVE_JSON" | jq -c .)}")
			fi
		fi
	done <<< "$template_names"

	log_info_stderr "Retrieval process completed. Retrieved: $retrieved_count, Failed: $failed_count"

	# Build result JSON
	local results_json
	results_json=$(printf '%s\n' "${retrieval_results[@]}" | jq -s .)
	local final_result
	final_result=$(jq -n \
		--argjson templates_found "$template_count" \
		--argjson templates_retrieved "$retrieved_count" \
		--argjson templates_failed "$failed_count" \
		--argjson results "$results_json" \
		'{
			templates_found: $templates_found,
			templates_retrieved: $templates_retrieved,
			templates_failed: $templates_failed,
			results: $results
		}')

	local SUCCESS_STATUS="OK"
	local message="Email template retrieval completed. Retrieved $retrieved_count of $template_count templates from folder '$FOLDER_DEVELOPER_NAME'"

	log_debug_stderr "Preparing output in requested format"
	if [ "$JSON_OUTPUT" = true ]; then
		log_debug_stderr "Outputting structured JSON format"
		print_standard_json "$SUCCESS_STATUS" "$message" "$final_result"
	else
		log_debug_stderr "Outputting human-readable format"
		print_standard_block "$SUCCESS_STATUS" "$message" "$final_result"
	fi

	log_info_stderr "Email template retrieval process completed successfully"
	
	# Exit with error code if any templates failed to retrieve
	if [ $failed_count -gt 0 ]; then
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

	log_debug_stderr "Starting retrieve-email-templates.sh with arguments: $*"
	
	if [ -n "$TARGET_ORG" ]; then
		log_info_stderr "Parsed arguments - Folder: '$FOLDER_DEVELOPER_NAME', Target Org: '$TARGET_ORG', JSON output: $JSON_OUTPUT, Debug level: ${DEBUG_LEVEL:-NONE}, Log file: ${LOG_FILE:-NONE}"
	else
		log_info_stderr "Parsed arguments - Folder: '$FOLDER_DEVELOPER_NAME', Target Org: default, JSON output: $JSON_OUTPUT, Debug level: ${DEBUG_LEVEL:-NONE}, Log file: ${LOG_FILE:-NONE}"
	fi

	validate_args
	log_debug_stderr "Argument validation completed successfully"

	check_dependencies
	log_debug_stderr "Dependency checks completed successfully"

	retrieve_email_templates
	log_debug_stderr "Script execution completed successfully"
}

main "$@"
