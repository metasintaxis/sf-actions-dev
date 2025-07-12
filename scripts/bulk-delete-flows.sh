#!/bin/bash

# -----------------------------------------------------------------------------
# @file bulk-delete-flows.sh
# @brief Bulk delete flow versions by iterating over flows in force-app/main/default/flows
#
# @description
#   This script iterates over all flow definition files in force-app/main/default/flows
#   and uses the delete-flow.sh script to delete flow versions with a specified status.
#   It provides comprehensive reporting and error handling for bulk operations.
#
# @usage
#   ./bulk-delete-flows.sh -s <status> [-o <target-org>] [--json] [--log FILE] [--debug [LEVEL]] [--dry-run]
#   ./bulk-delete-flows.sh --status <status> [--target-org <target-org>] [--json] [--log FILE] [--debug [LEVEL]] [--dry-run]
#
# @options
#   -s, --status          The status of the flow versions to delete (e.g., Obsolete, Draft, Active).
#   -o, --target-org      The alias or username of the target Salesforce org (optional).
#   --json                Output result and errors in JSON format.
#   --log FILE            Write debug and operational logs to specified file
#   --debug [LEVEL]       Enable debug logging to stderr. Optional LEVEL:
#                         DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY
#                         (default: DEBUG if no level specified)
#   --dry-run             Show what would be deleted without actually deleting
#   -h, --help            Show this help message and exit.
#
# @example
#   ./bulk-delete-flows.sh -s "Obsolete" --dry-run
#   ./bulk-delete-flows.sh --status "Draft" --target-org my-org --json
#
# @exitcodes
#   0  Success
#   1  Missing required arguments, invalid usage, or error during execution
# -----------------------------------------------------------------------------

set -euo pipefail

# Get the directory of the current script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/bash/lib/output-utils.sh"
source "${SCRIPT_DIR}/bash/lib/logging/watts/logging.sh"

# Default values for arguments
FLOW_STATUS=""
TARGET_ORG=""
JSON_OUTPUT=false
DEBUG_LEVEL=""
LOG_FILE=""
DRY_RUN=false

# Path to the delete-flow script
DELETE_FLOW_SCRIPT="${SCRIPT_DIR}/delete-flow/bash/delete-flow.sh"

# Path to flows directory
FLOWS_DIR="force-app/main/default/flows"

show_usage() {
	echo "Usage:"
	echo "  $0 -s <status> [-o <target-org>] [--json] [--log FILE] [--debug [LEVEL]] [--dry-run]"
	echo "  $0 --status <status> [--target-org <target-org>] [--json] [--log FILE] [--debug [LEVEL]] [--dry-run]"
	echo
	echo "Options:"
	echo "  -s, --status          The status of the flow versions to delete (e.g., Obsolete, Draft, Active)."
	echo "  -o, --target-org      The alias or username of the target Salesforce org (optional)."
	echo "  --json                Output result and errors in JSON format."
	echo "  --log FILE            Write debug and operational logs to specified file"
	echo "  --debug [LEVEL]       Enable debug logging to stderr. Optional LEVEL:"
	echo "                        DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY"
	echo "                        (default: DEBUG if no level specified)"
	echo "  --dry-run             Show what would be deleted without actually deleting"
	echo "  -h, --help            Show this help message and exit."
	echo
	echo "Examples:"
	echo "  $0 -s \"Obsolete\" --dry-run"
	echo "  $0 --status \"Draft\" --target-org my-org --json"
	echo "  $0 -s \"Obsolete\" --log \"./bulk-deletion.log\" --debug INFO"
}

parse_args() {
	FLOW_STATUS=""
	TARGET_ORG=""
	JSON_OUTPUT=false
	DEBUG_LEVEL=""
	LOG_FILE=""
	DRY_RUN=false

	while [[ $# -gt 0 ]]; do
		case "$1" in
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
			--dry-run)
				DRY_RUN=true
				shift
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

	# Check if delete-flow script exists
	if [ ! -f "$DELETE_FLOW_SCRIPT" ]; then
		log_error_stderr "Missing dependency: delete-flow.sh script not found at $DELETE_FLOW_SCRIPT"
		local msg="Error: delete-flow.sh script not found."
		local detail="Expected location: $DELETE_FLOW_SCRIPT"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "MISSING_DEPENDENCY" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "MISSING_DEPENDENCY" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
	log_debug_stderr "delete-flow.sh script found"

	# Check if delete-flow script is executable
	if [ ! -x "$DELETE_FLOW_SCRIPT" ]; then
		log_warn_stderr "delete-flow.sh script is not executable, attempting to make it executable"
		chmod +x "$DELETE_FLOW_SCRIPT" || {
			log_error_stderr "Failed to make delete-flow.sh script executable"
			local msg="Error: Cannot execute delete-flow.sh script."
			local detail="Failed to set executable permissions on $DELETE_FLOW_SCRIPT"
			local func="${FUNCNAME[0]}"
			if [ "$JSON_OUTPUT" = true ]; then
				print_error_json "$msg" "$detail" "PERMISSION_ERROR" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
			else
				print_error_block "$msg" "$detail" "PERMISSION_ERROR" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
			fi
			exit 1
		}
	fi
	log_debug_stderr "delete-flow.sh script is executable"

	# Check if flows directory exists
	if [ ! -d "$FLOWS_DIR" ]; then
		log_error_stderr "Flows directory not found: $FLOWS_DIR"
		local msg="Error: Flows directory not found."
		local detail="Expected location: $FLOWS_DIR. Make sure you're running this from the project root."
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "MISSING_DIRECTORY" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "MISSING_DIRECTORY" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
	log_debug_stderr "Flows directory found: $FLOWS_DIR"

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

# Function to extract flow developer names from .flow-meta.xml files
discover_flows() {
	log_info_stderr "Discovering flows in $FLOWS_DIR"
	
	local flow_files=()
	local flow_names=()
	
	# Find all .flow-meta.xml files
	while IFS= read -r -d '' file; do
		flow_files+=("$file")
	done < <(find "$FLOWS_DIR" -name "*.flow-meta.xml" -print0 2>/dev/null)
	
	local flow_count=${#flow_files[@]}
	log_info_stderr "Found $flow_count flow definition files"
	
	if [ $flow_count -eq 0 ]; then
		log_info_stderr "No flow definition files found in $FLOWS_DIR"
		return 0
	fi
	
	# Extract developer names from file names
	for file in "${flow_files[@]}"; do
		local basename=$(basename "$file" .flow-meta.xml)
		flow_names+=("$basename")
		log_debug_stderr "Discovered flow: $basename"
	done
	
	# Return flow names as newline-separated string
	printf '%s\n' "${flow_names[@]}"
}

# Function to delete flows for a single flow developer name
delete_single_flow() {
	local developer_name="$1"
	local delete_args=()
	
	# Build arguments for delete-flow script
	delete_args+=("--developer-name" "$developer_name")
	delete_args+=("--status" "$FLOW_STATUS")
	
	if [ -n "$TARGET_ORG" ]; then
		delete_args+=("--target-org" "$TARGET_ORG")
	fi
	
	if [ "$JSON_OUTPUT" = true ]; then
		delete_args+=("--json")
	fi
	
	if [ -n "$LOG_FILE" ]; then
		delete_args+=("--log" "$LOG_FILE")
	fi
	
	if [ -n "$DEBUG_LEVEL" ]; then
		delete_args+=("--debug" "$DEBUG_LEVEL")
	fi
	
	log_debug_stderr "Executing delete-flow script with args: ${delete_args[*]}"
	
	if [ "$DRY_RUN" = true ]; then
		log_info_stderr "[DRY RUN] Would execute: $DELETE_FLOW_SCRIPT ${delete_args[*]}"
		echo '{"status": "OK", "message": "DRY RUN - No actual deletion performed", "detail": {"deletedRecords": 0, "records": []}}'
		return 0
	else
		"$DELETE_FLOW_SCRIPT" "${delete_args[@]}"
	fi
}

# Main bulk deletion function
bulk_delete_flows() {
	log_info_stderr "Starting bulk flow deletion process"
	log_debug_stderr "Processing flows with status: '$FLOW_STATUS'"
	
	if [ "$DRY_RUN" = true ]; then
		log_info_stderr "DRY RUN MODE: No actual deletions will be performed"
	fi
	
	# Discover all flows
	local flow_names
	flow_names=$(discover_flows)
	
	if [ -z "$flow_names" ]; then
		log_info_stderr "No flows found to process"
		local msg="No flows found in $FLOWS_DIR"
		local detail='{"flows_processed": 0, "flows_succeeded": 0, "flows_failed": 0, "results": []}'
		if [ "$JSON_OUTPUT" = true ]; then
			print_standard_json "OK" "$msg" "$detail"
		else
			print_standard_block "OK" "$msg" "$detail"
		fi
		return 0
	fi
	
	# Count flows
	local total_flows
	total_flows=$(echo "$flow_names" | wc -l)
	log_info_stderr "Processing $total_flows flows for status '$FLOW_STATUS'"
	
	# Initialize counters
	local processed_count=0
	local succeeded_count=0
	local failed_count=0
	local results=()
	
	# Process each flow
	while IFS= read -r developer_name; do
		if [ -n "$developer_name" ]; then
			processed_count=$((processed_count + 1))
			log_info_stderr "Processing flow $processed_count/$total_flows: $developer_name"
					# Execute delete-flow script
		local delete_result
		local delete_status=0
		
		# Only redirect stdout to capture structured output, let stderr (debug logs) flow through
		delete_result=$(delete_single_flow "$developer_name") || delete_status=$?
			
			if [ $delete_status -eq 0 ]; then
				log_info_stderr "Successfully processed flow: $developer_name"
				succeeded_count=$((succeeded_count + 1))
				
				# Extract deletion count from result if possible
				local deleted_count=0
				if echo "$delete_result" | jq -e '.detail.deletedRecords' > /dev/null 2>&1; then
					deleted_count=$(echo "$delete_result" | jq -r '.detail.deletedRecords')
				fi
				
				results+=("{\"flow\": \"$developer_name\", \"status\": \"success\", \"deletedVersions\": $deleted_count}")
			else
				log_error_stderr "Failed to process flow: $developer_name"
				failed_count=$((failed_count + 1))
				
				# Try to extract error message
				local error_msg="Unknown error"
				if echo "$delete_result" | jq -e '.message' > /dev/null 2>&1; then
					error_msg=$(echo "$delete_result" | jq -r '.message')
				fi
				
				results+=("{\"flow\": \"$developer_name\", \"status\": \"failed\", \"error\": \"$error_msg\"}")
			fi
		fi
	done <<< "$flow_names"
	
	log_info_stderr "Bulk deletion process completed. Processed: $processed_count, Succeeded: $succeeded_count, Failed: $failed_count"
	
	# Build final result JSON
	local results_json
	results_json=$(printf '%s\n' "${results[@]}" | jq -s .)
	local final_result
	final_result=$(jq -n \
		--argjson flows_processed "$processed_count" \
		--argjson flows_succeeded "$succeeded_count" \
		--argjson flows_failed "$failed_count" \
		--argjson results "$results_json" \
		'{
			flows_processed: $flows_processed,
			flows_succeeded: $flows_succeeded,
			flows_failed: $flows_failed,
			results: $results
		}')
	
	local SUCCESS_STATUS="OK"
	local message
	if [ "$DRY_RUN" = true ]; then
		message="Bulk flow deletion dry run completed. Would process $processed_count flows with status '$FLOW_STATUS'"
	else
		message="Bulk flow deletion completed. Successfully processed $succeeded_count of $processed_count flows with status '$FLOW_STATUS'"
	fi
	
	log_debug_stderr "Preparing output in requested format"
	if [ "$JSON_OUTPUT" = true ]; then
		log_debug_stderr "Outputting structured JSON format"
		print_standard_json "$SUCCESS_STATUS" "$message" "$final_result"
	else
		log_debug_stderr "Outputting human-readable format"
		print_standard_block "$SUCCESS_STATUS" "$message" "$final_result"
	fi
	
	log_info_stderr "Bulk flow deletion process completed successfully"
	
	# Exit with error code if any flows failed to process (unless dry run)
	if [ "$DRY_RUN" = false ] && [ $failed_count -gt 0 ]; then
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

	log_debug_stderr "Starting bulk-delete-flows.sh with arguments: $*"
	log_info_stderr "Parsed arguments - Status: '$FLOW_STATUS', Target org: '${TARGET_ORG:-default}', JSON output: $JSON_OUTPUT, Debug level: ${DEBUG_LEVEL:-NONE}, Log file: ${LOG_FILE:-NONE}, Dry run: $DRY_RUN"

	validate_args
	log_debug_stderr "Argument validation completed successfully"

	check_dependencies
	log_debug_stderr "Dependency checks completed successfully"

	bulk_delete_flows
	log_debug_stderr "Script execution completed successfully"
}

main "$@"
