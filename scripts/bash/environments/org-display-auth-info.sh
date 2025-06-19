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

TARGET_ORG=""
JSON_OUTPUT=false
SFDX_AUTH_URL_CONDENSED=false

show_usage() {
	echo "Usage:"
	echo "  $0 -o <target-org> [--json]"
	echo "  $0 --target-org <target-org> [--json]"
	echo "  $0 -o <target-org> --sfdx-auth-url-condensed"
	echo
	echo "Options:"
	echo "  -o, --target-org                The alias or username of the target Salesforce org."
	echo "  -h, --help                      Show this help message and exit."
	echo "  --json                          Output result and errors in JSON format."
	echo "  --sfdx-auth-url-condensed       Output only the raw JSON from sf in a single line."
}

parse_args() {
	JSON_OUTPUT=false
	SFDX_AUTH_URL_CONDENSED=false
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
	if ! command -v jq > /dev/null 2>&1; then
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

	if ! command -v sf > /dev/null 2>&1; then
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
}

validate_args() {
	if [ -z "$TARGET_ORG" ]; then
		local msg="Error: target org must be specified with -o/--target-org"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "Use -o/--target-org" "MISSING_ARGUMENTS" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "Use -o/--target-org" "MISSING_ARGUMENTS" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
}

run_sf_command() {
	if ! FINAL_JSON=$(sf org display --target-org "$TARGET_ORG" --verbose --json 2> /dev/null); then
		local msg="Failed to retrieve org authentication information for '$TARGET_ORG'."
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$FINAL_JSON" "ORG_DISPLAY_FAILED" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$FINAL_JSON" "ORG_DISPLAY_FAILED" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
}

output_final_result() {
	local SUCCESS_STATUS="OK"
	local message="Org authentication information retrieved successfully."
	local detail="$FINAL_JSON"
	if [ "$SFDX_AUTH_URL_CONDENSED" = true ]; then
		echo "$FINAL_JSON" | jq -c .
	elif [ "$JSON_OUTPUT" = true ]; then
		print_standard_json "$SUCCESS_STATUS" "$message" "$detail"
	else
		print_standard_block "$SUCCESS_STATUS" "$message" "$detail"
	fi
}

check_no_args() {
	if [ $# -eq 0 ]; then
		show_usage
		exit 1
	fi
}

main() {
	check_no_args "$@"
	parse_args "$@"
	validate_args
	check_dependencies
	run_sf_command
	output_final_result
}

main "$@"
