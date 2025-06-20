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
#   ./find-metadata-dependencies.sh -o OBJECT [-n NAME] [-d DEVELOPER_NAME] [-m MASTER_LABEL] [--json]
#   ./find-metadata-dependencies.sh --object OBJECT [--name NAME] [--developer-name DEVELOPER_NAME] [--master-label MASTER_LABEL] [--json]
#
# @options
#   -o, --object           The sObject type (e.g., FlowDefinition, ApexClass, etc.) (required)
#   -n, --name             The Name of the component (optional)
#   -d, --developer-name   The DeveloperName of the component (optional)
#   -m, --master-label     The MasterLabel of the component (optional)
#   --json                 Output result and errors in JSON format.
#   -h, --help             Show this help message and exit.
#
# @exitcodes
#   0  Success
#   1  Missing required arguments, invalid usage, or error during execution
# -----------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../bash/lib/output-utils.sh"

show_usage() {
	echo "Usage:"
	echo "  $0 -o OBJECT [-n NAME] [-d DEVELOPER_NAME] [-m MASTER_LABEL] [--json]"
	echo "  $0 --object OBJECT [--name NAME] [--developer-name DEVELOPER_NAME] [--master-label MASTER_LABEL] [--json]"
	echo
	echo "Options:"
	echo "  -o, --object           The sObject type (e.g., FlowDefinition, ApexClass, etc.) (required)"
	echo "  -n, --name             The Name of the component (optional)"
	echo "  -d, --developer-name   The DeveloperName of the component (optional)"
	echo "  -m, --master-label     The MasterLabel of the component (optional)"
	echo "  --json                 Output result and errors in JSON format."
	echo "  -h, --help             Show this help message and exit."
}

parse_args() {
	local OBJECT=""
	local NAME=""
	local DEVELOPER_NAME=""
	local MASTER_LABEL=""
	local JSON_OUTPUT=false

	while [[ $# -gt 0 ]]; do
		case "$1" in
			-o | --object)
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
			--json)
				JSON_OUTPUT=true
				shift
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

	echo "$OBJECT|$NAME|$DEVELOPER_NAME|$MASTER_LABEL|$JSON_OUTPUT"
}

validate_args() {
	local OBJECT="$1"
	local NAME="$2"
	local DEVELOPER_NAME="$3"
	local MASTER_LABEL="$4"
	local JSON_OUTPUT="$5"
	if [ -z "$OBJECT" ] || { [ -z "$NAME" ] && [ -z "$DEVELOPER_NAME" ] && [ -z "$MASTER_LABEL" ]; }; then
		local msg="Error: object and at least one of name, developer-name, or master-label must be specified"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "" "MISSING_ARGUMENTS" "${LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "" "MISSING_ARGUMENTS" "${LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
}

check_dependencies() {
	local JSON_OUTPUT="$1"
	if ! command -v sf > /dev/null 2>&1; then
		local msg="Error: Salesforce CLI (sf) is not installed."
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "Install Salesforce CLI to continue." "MISSING_DEPENDENCY" "${LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "Install Salesforce CLI to continue." "MISSING_DEPENDENCY" "${LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
	if ! command -v jq > /dev/null 2>&1; then
		local msg="Error: jq is required but not installed."
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "Install jq to continue." "MISSING_DEPENDENCY" "${LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "Install jq to continue." "MISSING_DEPENDENCY" "${LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
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
	sf data query --query "$query" --use-tooling-api --json
}

fetch_component_id_json() {
	local OBJECT="$1"
	local FIELD="$2"
	local VALUE="$3"
	get_component_id_json "$OBJECT" "$FIELD" "$VALUE"
}

is_sf_error_json() {
	echo "$1" | jq -e 'has("status") and .status == 1' > /dev/null 2>&1
}

query_dependencies() {
	local object="$1"
	local component_id="$2"
	local dep_query="SELECT RefMetadataComponentName, RefMetadataComponentId, RefMetadataComponentType, MetadataComponentId, MetadataComponentName, MetadataComponentType FROM MetadataComponentDependency WHERE RefMetadataComponentType = '$object' AND RefMetadataComponentId = '$component_id'"
	sf data query --query "$dep_query" --use-tooling-api --json
}

# Refactored: Only queries and returns result, does not print or exit
fetch_dependencies() {
	local OBJECT="$1"
	local COMPONENT_ID="$2"
	query_dependencies "$OBJECT" "$COMPONENT_ID"
}

check_component_json() {
	local fetch_status="$1"
	local COMPONENT_JSON="$2"
	local JSON_OUTPUT="$3"
	if [ "$fetch_status" -ne 0 ] || is_sf_error_json "$COMPONENT_JSON"; then
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "Failed to get component Id." "$COMPONENT_JSON" "GET_COMPONENT_ID_FAILED" "${LINENO[0]}" "${BASH_SOURCE[0]}" "${FUNCNAME[0]}"
		else
			print_error_block "Failed to get component Id." "$COMPONENT_JSON" "GET_COMPONENT_ID_FAILED" "${LINENO[0]}" "${BASH_SOURCE[0]}" "${FUNCNAME[0]}"
		fi
		exit 1
	fi
}

get_component_id() {
	local component_json="$1"
	echo "$component_json" | jq -r '.result.records[0].Id // empty'
}

check_component_id() {
	local component_id="$1"
	local component_json="$2"
	local json_output="$3"
	if [ -z "$component_id" ] || [ "$component_id" = "null" ]; then
		if [ "$json_output" = true ]; then
			print_error_json "Could not find Id for the specified component." "$component_json" "ID_NOT_FOUND" "${LINENO[0]}" "${BASH_SOURCE[0]}" "${FUNCNAME[0]}"
		else
			print_error_block "Could not find Id for the specified component." "$component_json" "ID_NOT_FOUND" "${LINENO[0]}" "${BASH_SOURCE[0]}" "${FUNCNAME[0]}"
		fi
		exit 1
	fi
}

main() {
	local parsed
	parsed=$(parse_args "$@")
	IFS='|' read -r OBJECT NAME DEVELOPER_NAME MASTER_LABEL JSON_OUTPUT <<< "$parsed"

	validate_args "$OBJECT" "$NAME" "$DEVELOPER_NAME" "$MASTER_LABEL" "$JSON_OUTPUT"
	check_dependencies "$JSON_OUTPUT"

	IFS='|' read -r SEARCH_FIELD SEARCH_VALUE <<< "$(get_search_field_and_value "$NAME" "$DEVELOPER_NAME" "$MASTER_LABEL")"

	# Capture output and status without exiting on error
	local COMPONENT_JSON
	local fetch_status=0
	COMPONENT_JSON=$(fetch_component_id_json "$OBJECT" "$SEARCH_FIELD" "$SEARCH_VALUE") || fetch_status=$?
	check_component_json "$fetch_status" "$COMPONENT_JSON" "$JSON_OUTPUT"

	# Extract Id
	local COMPONENT_ID
	COMPONENT_ID=$(get_component_id "$COMPONENT_JSON")
	check_component_id "$COMPONENT_ID" "$COMPONENT_JSON" "$JSON_OUTPUT"

	# Fetch dependencies and handle errors here
	local DEPS_JSON
	local deps_status=0
	DEPS_JSON=$(fetch_dependencies "$OBJECT" "$COMPONENT_ID") || deps_status=$?

	if [ $deps_status -ne 0 ] || is_sf_error_json "$DEPS_JSON"; then
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "Failed to query dependencies." "$DEPS_JSON" "QUERY_DEPENDENCIES_FAILED" "${LINENO[0]}" "${BASH_SOURCE[0]}" "${FUNCNAME[0]}"
		else
			print_error_block "Failed to query dependencies." "$DEPS_JSON" "QUERY_DEPENDENCIES_FAILED" "${LINENO[0]}" "${BASH_SOURCE[0]}" "${FUNCNAME[0]}"
		fi
		exit 1
	fi

	if [ "$JSON_OUTPUT" = true ]; then
		print_standard_json "OK" "Dependencies retrieved successfully." "$DEPS_JSON"
	else
		print_standard_block "OK" "Dependencies retrieved successfully." "$DEPS_JSON"
	fi
}

if [ "${ACTIONS_STEP_DEBUG:-false}" = "true" ]; then
  set -x
  echo "Debug mode enabled: Bash tracing is ON" >&2
fi

main "$@"
