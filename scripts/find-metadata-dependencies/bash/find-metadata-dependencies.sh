#!/bin/bash

# -----------------------------------------------------------------------------
# @file scripts/find-metadata-dependencies/bash/find-metadata-dependencies.sh
# @brief Find dependencies for a Salesforce metadata component using SOQL.
#
# @description
#   This script retrieves dependencies for a specified Salesforce metadata component
#   using the Salesforce CLI and outputs the result in JSON or human-readable format.
#   It is designed for use in CI/CD pipelines and supports robust error handling.
#
# @usage
#   ./find-metadata-dependencies.sh -s OBJECT [-n NAME] [-d DEVELOPER_NAME] [-m MASTER_LABEL] [-o TARGET_ORG] [--json] [--debug [LEVEL]]
#   ./find-metadata-dependencies.sh --sobject OBJECT [--name NAME] [--developer-name DEVELOPER_NAME] [--master-label MASTER_LABEL] [--target-org TARGET_ORG] [--json] [--debug [LEVEL]]
#
# @options
#   -s, --sobject          The sObject type (e.g., FlowDefinition, ApexClass, etc.) (required)
#   -n, --name             The Name of the component (optional)
#   -d, --developer-name   The DeveloperName of the component (optional)
#   -m, --master-label     The MasterLabel of the component (optional)
#   -o, --target-org       The alias or username of the target Salesforce org (optional, uses default org if not specified)
#   --json                 Output result and errors in JSON format.
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../bash/lib/output-utils.sh"
source "${SCRIPT_DIR}/../../bash/lib/logging/watts/logging.sh"

# Global variables
DEBUG_LEVEL=""

show_usage() {
	echo "Usage:"
	echo "  $0 -s OBJECT [-n NAME] [-d DEVELOPER_NAME] [-m MASTER_LABEL] [-o TARGET_ORG] [--json] [--debug [LEVEL]]"
	echo "  $0 --sobject OBJECT [--name NAME] [--developer-name DEVELOPER_NAME] [--master-label MASTER_LABEL] [--target-org TARGET_ORG] [--json] [--debug [LEVEL]]"
	echo
	echo "Options:"
	echo "  -s, --sobject          The sObject type (e.g., FlowDefinition, ApexClass, etc.) (required)"
	echo "  -n, --name             The Name of the component (optional)"
	echo "  -d, --developer-name   The DeveloperName of the component (optional)"
	echo "  -m, --master-label     The MasterLabel of the component (optional)"
	echo "  -o, --target-org       The alias or username of the target Salesforce org (optional, uses default org if not specified)"
	echo "  --json                 Output result and errors in JSON format."
	echo "  --debug [LEVEL]        Enable debug logging to stderr. Optional LEVEL:"
	echo "                         DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY"
	echo "                         (default: DEBUG if no level specified)"
	echo "  -h, --help             Show this help message and exit."
}

parse_args() {
	local OBJECT=""
	local NAME=""
	local DEVELOPER_NAME=""
	local MASTER_LABEL=""
	TARGET_ORG=""
	local JSON_OUTPUT=false
	DEBUG_LEVEL=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
			-s | --sobject)
				OBJECT="$2"
				shift 2
				;;
			-n | --name)
				NAME="$2"
				shift 2
				;;
			-d | --developer-name)
				DEVELOPER_NAME="$2"
				shift 2
				;;
			-m | --master-label)
				MASTER_LABEL="$2"
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
				show_usage
				exit 1
				;;
		esac
	done

	echo "$OBJECT|$NAME|$DEVELOPER_NAME|$MASTER_LABEL|$TARGET_ORG|$JSON_OUTPUT|$DEBUG_LEVEL"
}

validate_args() {
	local OBJECT="$1"
	local NAME="$2"
	local DEVELOPER_NAME="$3"
	local MASTER_LABEL="$4"
	local JSON_OUTPUT="$5"

	log_debug_stderr "Validating required arguments"
	if [ -z "$OBJECT" ] || { [ -z "$NAME" ] && [ -z "$DEVELOPER_NAME" ] && [ -z "$MASTER_LABEL" ]; }; then
		log_error_stderr "Missing required arguments: sobject and at least one of name, developer-name, or master-label must be specified"
		local msg="Error: sobject and at least one of name, developer-name, or master-label must be specified"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "" "MISSING_ARGUMENTS" "${LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "" "MISSING_ARGUMENTS" "${LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
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
			print_error_json "$msg" "Install Salesforce CLI to continue." "MISSING_DEPENDENCY" "${LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "Install Salesforce CLI to continue." "MISSING_DEPENDENCY" "${LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
	log_debug_stderr "Salesforce CLI dependency check passed"

	if ! command -v jq > /dev/null 2>&1; then
		log_error_stderr "Missing dependency: jq is not installed"
		local msg="Error: jq is required but not installed."
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "Install jq to continue." "MISSING_DEPENDENCY" "${LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "Install jq to continue." "MISSING_DEPENDENCY" "${LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
	log_debug_stderr "jq dependency check passed"
}

get_search_field_and_value() {
	local NAME="$1"
	local DEVELOPER_NAME="$2"
	local MASTER_LABEL="$3"
	if [ -n "$NAME" ]; then
		echo "Name|$NAME"
	elif [ -n "$DEVELOPER_NAME" ]; then
		echo "DeveloperName|$DEVELOPER_NAME"
	elif [ -n "$MASTER_LABEL" ]; then
		echo "MasterLabel|$MASTER_LABEL"
	else
		echo "|"
	fi
}

get_component_id_json() {
	local OBJECT="$1"
	local FIELD="$2"
	local VALUE="$3"
	local query="SELECT Id FROM $OBJECT WHERE $FIELD = '$VALUE' LIMIT 1"

	log_debug_stderr "Executing component ID query: $query"
	sf data query --query "$query" --use-tooling-api --json
}

fetch_component_id_json() {
	local OBJECT="$1"
	local FIELD="$2"
	local VALUE="$3"

	log_info_stderr "Fetching component ID for $OBJECT where $FIELD = '$VALUE'"
	get_component_id_json "$OBJECT" "$FIELD" "$VALUE"
}

is_sf_error_json() {
	echo "$1" | jq -e 'has("status") and .status == 1' > /dev/null 2>&1
}

query_dependencies() {
	local object="$1"
	local component_id="$2"
	local dep_query="SELECT RefMetadataComponentName, RefMetadataComponentId, RefMetadataComponentType, MetadataComponentId, MetadataComponentName, MetadataComponentType FROM MetadataComponentDependency WHERE RefMetadataComponentType = '$object' AND RefMetadataComponentId = '$component_id'"

	log_debug_stderr "Executing dependencies query: $dep_query"
	sf data query --query "$dep_query" --use-tooling-api --json
}

# Refactored: Only queries and returns result, does not print or exit
fetch_dependencies() {
	local OBJECT="$1"
	local COMPONENT_ID="$2"

	log_info_stderr "Fetching dependencies for $OBJECT with ID: '$COMPONENT_ID'"
	query_dependencies "$OBJECT" "$COMPONENT_ID"
}

check_component_json() {
	local fetch_status="$1"
	local COMPONENT_JSON="$2"
	local JSON_OUTPUT="$3"

	log_debug_stderr "Validating component JSON response (status: $fetch_status)"
	if [ "$fetch_status" -ne 0 ] || is_sf_error_json "$COMPONENT_JSON"; then
		log_error_stderr "Failed to get component Id"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "Failed to get component Id." "$COMPONENT_JSON" "GET_COMPONENT_ID_FAILED" "${LINENO[0]}" "${BASH_SOURCE[0]}" "${FUNCNAME[0]}"
		else
			print_error_block "Failed to get component Id." "$COMPONENT_JSON" "GET_COMPONENT_ID_FAILED" "${LINENO[0]}" "${BASH_SOURCE[0]}" "${FUNCNAME[0]}"
		fi
		exit 1
	fi
	log_debug_stderr "Component JSON validation passed"
}

get_component_id() {
	local component_json="$1"
	local component_id
	component_id=$(echo "$component_json" | jq -r '.result.records[0].Id // empty')

	log_debug_stderr "Extracted component ID: '$component_id'"
	echo "$component_id"
}

check_component_id() {
	local component_id="$1"
	local component_json="$2"
	local json_output="$3"

	log_debug_stderr "Validating extracted component ID: '$component_id'"
	if [ -z "$component_id" ] || [ "$component_id" = "null" ]; then
		log_error_stderr "Could not find Id for the specified component"
		if [ "$json_output" = true ]; then
			print_error_json "Could not find Id for the specified component." "$component_json" "ID_NOT_FOUND" "${LINENO[0]}" "${BASH_SOURCE[0]}" "${FUNCNAME[0]}"
		else
			print_error_block "Could not find Id for the specified component." "$component_json" "ID_NOT_FOUND" "${LINENO[0]}" "${BASH_SOURCE[0]}" "${FUNCNAME[0]}"
		fi
		exit 1
	fi
	log_debug_stderr "Component ID validation passed"
}

enable_bash_debug() {
	if [ "${ACTIONS_STEP_DEBUG:-false}" = "true" ]; then
		# Initialize logger with DEBUG level if ACTIONS_STEP_DEBUG is true
		if [ -z "$DEBUG_LEVEL" ]; then
			DEBUG_LEVEL="DEBUG"
		fi
		init_logger --level "$DEBUG_LEVEL"
		log_info_stderr "GitHub Actions step debug mode detected"
		log_debug_stderr "Enabling bash tracing for detailed execution debugging"
		set -x
		echo "Debug mode enabled: Bash tracing is ON" >&2
	fi
}

# Function to initialize logging based on environment and arguments
init_script_logging() {
	local debug_level="$1"

	# Determine the effective debug level
	local effective_level=""

	if [ "${ACTIONS_STEP_DEBUG:-false}" = "true" ]; then
		# GitHub Actions debug mode takes precedence
		effective_level="${debug_level:-DEBUG}"
		log_info_stderr "GitHub Actions step debug mode detected"
		log_debug_stderr "Enabling bash tracing for detailed execution debugging"
		set -x
		echo "Debug mode enabled: Bash tracing is ON" >&2
	elif [ -n "$debug_level" ]; then
		# Manual debug flag provided
		effective_level="$debug_level"
		log_debug_stderr "Debug mode enabled with level: $effective_level"
	else
		# Default level
		effective_level="INFO"
	fi

	init_logger --level "$effective_level"
	log_debug_stderr "Logger initialized with level: $effective_level"
}

main() {
	if [ $# -eq 0 ]; then
		show_usage
		exit 1
	fi

	local parsed
	parsed=$(parse_args "$@")
	IFS='|' read -r OBJECT NAME DEVELOPER_NAME MASTER_LABEL TARGET_ORG JSON_OUTPUT DEBUG_LEVEL <<< "$parsed"

	# Initialize logging in one place
	init_script_logging "$DEBUG_LEVEL"

	log_debug_stderr "Starting find-metadata-dependencies.sh with arguments: $*"

	if [ -n "$TARGET_ORG" ]; then
		log_info_stderr "Parsed arguments - sObject: '$OBJECT', Name: '$NAME', Developer Name: '$DEVELOPER_NAME', Master Label: '$MASTER_LABEL', Target Org: '$TARGET_ORG', JSON output: $JSON_OUTPUT, Debug level: ${DEBUG_LEVEL:-NONE}"
	else
		log_info_stderr "Parsed arguments - sObject: '$OBJECT', Name: '$NAME', Developer Name: '$DEVELOPER_NAME', Master Label: '$MASTER_LABEL', Target Org: default, JSON output: $JSON_OUTPUT, Debug level: ${DEBUG_LEVEL:-NONE}"
	fi

	validate_args "$OBJECT" "$NAME" "$DEVELOPER_NAME" "$MASTER_LABEL" "$JSON_OUTPUT"
	log_debug_stderr "Argument validation completed successfully"

	check_dependencies "$JSON_OUTPUT"
	log_debug_stderr "Dependency checks completed successfully"

	IFS='|' read -r SEARCH_FIELD SEARCH_VALUE <<< "$(get_search_field_and_value "$NAME" "$DEVELOPER_NAME" "$MASTER_LABEL")"
	log_debug_stderr "Using search criteria - Field: '$SEARCH_FIELD', Value: '$SEARCH_VALUE'"

	# Capture output and status without exiting on error
	local COMPONENT_JSON
	local fetch_status=0
	COMPONENT_JSON=$(fetch_component_id_json "$OBJECT" "$SEARCH_FIELD" "$SEARCH_VALUE" "$TARGET_ORG") || fetch_status=$?
	check_component_json "$fetch_status" "$COMPONENT_JSON" "$JSON_OUTPUT"

	# Extract Id
	local COMPONENT_ID
	COMPONENT_ID=$(get_component_id "$COMPONENT_JSON")
	check_component_id "$COMPONENT_ID" "$COMPONENT_JSON" "$JSON_OUTPUT"

	# Fetch dependencies and handle errors here
	local DEPS_JSON
	local deps_status=0
	DEPS_JSON=$(fetch_dependencies "$OBJECT" "$COMPONENT_ID" "$TARGET_ORG") || deps_status=$?

	log_debug_stderr "Dependencies query completed with status: $deps_status"
	if [ $deps_status -ne 0 ] || is_sf_error_json "$DEPS_JSON"; then
		log_error_stderr "Failed to query dependencies"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "Failed to query dependencies." "$DEPS_JSON" "QUERY_DEPENDENCIES_FAILED" "${LINENO[0]}" "${BASH_SOURCE[0]}" "${FUNCNAME[0]}"
		else
			print_error_block "Failed to query dependencies." "$DEPS_JSON" "QUERY_DEPENDENCIES_FAILED" "${LINENO[0]}" "${BASH_SOURCE[0]}" "${FUNCNAME[0]}"
		fi
		exit 1
	fi

	log_info_stderr "Successfully retrieved dependencies for component '$COMPONENT_ID'"
	log_debug_stderr "Preparing final output"

	if [ "$JSON_OUTPUT" = true ]; then
		log_debug_stderr "Outputting structured JSON format"
		print_standard_json "OK" "Dependencies retrieved successfully." "$DEPS_JSON"
	else
		log_debug_stderr "Outputting human-readable format"
		print_standard_block "OK" "Dependencies retrieved successfully." "$DEPS_JSON"
	fi

	log_debug_stderr "Script execution completed successfully"
}

main "$@"
