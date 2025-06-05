#!/bin/bash

# -----------------------------------------------------------------------------
# @file metadata-api-find-metadata-dependencies.sh
# @brief Find dependencies for a Salesforce metadata component using SOQL.
#
# @usage
#   ./metadata-api-find-metadata-dependencies.sh -o OBJECT [-n NAME] [-d DEVELOPER_NAME] [-m MASTER_LABEL] [--json]
#   ./metadata-api-find-metadata-dependencies.sh --object OBJECT [--name NAME] [--developer-name DEVELOPER_NAME] [--master-label MASTER_LABEL] [--json]
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
#   1  Missing required arguments or invalid usage
# -----------------------------------------------------------------------------

set -euo pipefail

OBJECT=""
NAME=""
DEVELOPER_NAME=""
MASTER_LABEL=""
JSON_OUTPUT=false

print_json_error() {
	local code="$1"
	local message="$2"
	local details="${3:-}"
	echo -n '{'
	echo -n "\"success\": false, \"error\": {\"code\": \"$code\", \"message\": \"$message\""
	if [ -n "$details" ]; then
		echo -n ", \"details\": \"$details\""
	fi
	echo '}}'
}

print_json_success() {
	local result="$1"
	echo -n '{'
	echo -n "\"success\": true, \"result\": $result"
	echo '}'
}

print_human_readable_success() {
	local deps_json="$1"
	local count
	count=$(echo "$deps_json" | jq '.result.records | length')
	echo "Found $count dependencies:"
	echo "$deps_json" | jq -r '.result.records[] | "- \(.MetadataComponentType): \(.MetadataComponentName) (Id: \(.MetadataComponentId))"' || true
}

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

check_dependencies() {
	if ! command -v sf > /dev/null 2>&1; then
		local msg="Error: Salesforce CLI (sf) is not installed."
		if [ "$JSON_OUTPUT" = true ]; then
			print_json_error "MISSING_DEPENDENCY" "$msg" "Install Salesforce CLI to continue."
		else
			echo "$msg" >&2
		fi
		exit 1
	fi
	if ! command -v jq > /dev/null 2>&1; then
		local msg="Error: jq is required but not installed."
		if [ "$JSON_OUTPUT" = true ]; then
			print_json_error "MISSING_DEPENDENCY" "$msg" "Install jq to continue."
		else
			echo "$msg" >&2
		fi
		exit 1
	fi
}

validate_args() {
	if [ -z "$OBJECT" ] || { [ -z "$NAME" ] && [ -z "$DEVELOPER_NAME" ] && [ -z "$MASTER_LABEL" ]; }; then
		local msg="Error: object and at least one of name, developer-name, or master-label must be specified"
		if [ "$JSON_OUTPUT" = true ]; then
			print_json_error "MISSING_ARGUMENTS" "$msg"
		else
			echo "$msg" >&2
		fi
		exit 1
	fi
}

parse_args() {
	JSON_OUTPUT=false
	while [[ $# -gt 0 ]]; do
		case "$1" in
			-o | --object)
				if [[ -z "${2:-}" || "${2:0:1}" == "-" ]]; then
					echo "Error: --object requires a value." >&2
					exit 1
				fi
				OBJECT="$2"
				shift 2
				;;
			-n | --name)
				if [[ -z "${2:-}" || "${2:0:1}" == "-" ]]; then
					echo "Error: --name requires a value." >&2
					exit 1
				fi
				NAME="$2"
				shift 2
				;;
			-d | --developer-name)
				if [[ -z "${2:-}" || "${2:0:1}" == "-" ]]; then
					echo "Error: --developer-name requires a value." >&2
					exit 1
				fi
				DEVELOPER_NAME="$2"
				shift 2
				;;
			-m | --master-label)
				if [[ -z "${2:-}" || "${2:0:1}" == "-" ]]; then
					echo "Error: --master-label requires a value." >&2
					exit 1
				fi
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
			-*)
				show_usage >&2
				exit 1
				;;
			*)
				break
				;;
		esac
	done
}

get_component_id() {
	local object="$1"
	local field="$2"
	local value="$3"
	local query="SELECT Id FROM $object WHERE $field = '$value' LIMIT 1"
	sf data query --query "$query" --use-tooling-api --json | jq -r '.result.records[0].Id'
}

query_dependencies() {
	local object="$1"
	local component_id="$2"
	local dep_query="SELECT RefMetadataComponentName, RefMetadataComponentId, RefMetadataComponentType, MetadataComponentId, MetadataComponentName, MetadataComponentType FROM MetadataComponentDependency WHERE RefMetadataComponentType = '$object' AND RefMetadataComponentId = '$component_id'"
	sf data query --query "$dep_query" --use-tooling-api --json
}

get_search_field_and_value() {
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

resolve_component_id() {
	local object="$1"
	local search_field="$2"
	local search_value="$3"
	get_component_id "$object" "$search_field" "$search_value"
}

get_dependencies_json() {
	local object="$1"
	local component_id="$2"
	query_dependencies "$object" "$component_id"
}

handle_component_id_error() {
	local error_msg="$1"
	if [ "$JSON_OUTPUT" = true ]; then
		print_json_error "GET_COMPONENT_ID_FAILED" "Failed to get component Id." "$error_msg"
	else
		echo "Failed to get component Id: $error_msg" >&2
	fi
}

handle_component_not_found() {
	local object="$1"
	local field="$2"
	local value="$3"
	local msg="Component not found for $object where $field = '$value'."
	if [ "$JSON_OUTPUT" = true ]; then
		print_json_error "COMPONENT_NOT_FOUND" "$msg"
	else
		echo "$msg" >&2
	fi
}

handle_query_dependencies_error() {
	local error_msg="$1"
	if [ "$JSON_OUTPUT" = true ]; then
		print_json_error "QUERY_DEPENDENCIES_FAILED" "Failed to query dependencies." "$error_msg"
	else
		echo "Failed to query dependencies: $error_msg" >&2
	fi
}

main() {
	parse_args "$@"
	validate_args
	check_dependencies

	# Get SEARCH_FIELD and SEARCH_VALUE as separate variables for clarity
	IFS='|' read -r SEARCH_FIELD SEARCH_VALUE <<< "$(get_search_field_and_value)"

	local COMPONENT_ID
	if ! COMPONENT_ID=$(resolve_component_id "$OBJECT" "$SEARCH_FIELD" "$SEARCH_VALUE" 2>&1); then
		handle_component_id_error "Id: $COMPONENT_ID"
		exit 1
	fi

	if [ -z "$COMPONENT_ID" ] || [ "$COMPONENT_ID" = "null" ]; then
		handle_component_not_found "$OBJECT" "$SEARCH_FIELD" "$SEARCH_VALUE"
		exit 1
	fi

	local DEPS_JSON
	if ! DEPS_JSON=$(get_dependencies_json "$OBJECT" "$COMPONENT_ID" 2>&1); then
		handle_query_dependencies_error "$DEPS_JSON"
		exit 1
	fi

	if [ "$JSON_OUTPUT" = true ]; then
		print_json_success "$DEPS_JSON"
	else
		print_human_readable_success "$DEPS_JSON"
	fi
}

main "$@"
