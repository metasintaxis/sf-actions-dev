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

TARGET_ORG=""
JSON_OUTPUT=false
SFDX_AUTH_URL_CONDENSED=false

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
	# Assumes $FINAL_JSON contains the JSON output
	local org_id
	local username
	local instance_url
	local login_url
	org_id=$(echo "$FINAL_JSON" | jq -r '.result.id // empty')
	username=$(echo "$FINAL_JSON" | jq -r '.result.username // empty')
	instance_url=$(echo "$FINAL_JSON" | jq -r '.result.instanceUrl // empty')
	login_url=$(echo "$FINAL_JSON" | jq -r '.result.loginUrl // empty')
	echo "Org authentication info retrieved successfully!"
	[ -n "$org_id" ] && echo "Org ID: $org_id"
	[ -n "$username" ] && echo "Username: $username"
	[ -n "$instance_url" ] && echo "Instance URL: $instance_url"
	[ -n "$login_url" ] && echo "Login URL: $login_url"
}

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
		if [ "$JSON_OUTPUT" = true ]; then
			print_json_error "MISSING_DEPENDENCY" "$msg" "Install jq to continue."
		else
			echo "$msg" >&2
		fi
		exit 1
	fi

	if ! command -v sf > /dev/null 2>&1; then
		local msg="Error: Salesforce CLI (sf) is not installed."
		if [ "$JSON_OUTPUT" = true ]; then
			print_json_error "MISSING_DEPENDENCY" "$msg" "Install Salesforce CLI to continue."
		else
			echo "$msg" >&2
		fi
		exit 1
	fi
}

validate_args() {
	if [ -z "$TARGET_ORG" ]; then
		local msg="Error: target org must be specified with -o/--target-org"
		if [ "$JSON_OUTPUT" = true ]; then
			print_json_error "MISSING_ARGUMENTS" "$msg" "Use -o/--target-org"
		else
			echo "$msg" >&2
		fi
		exit 1
	fi
}

run_sf_command() {
	if ! FINAL_JSON=$(sf org display --target-org "$TARGET_ORG" --verbose --json 2> /dev/null); then
		local msg="Error: Failed to display org info."
		if [ "$JSON_OUTPUT" = true ]; then
			print_json_error "ORG_DISPLAY_FAILED" "$msg"
		else
			echo "$msg" >&2
		fi
		exit 1
	fi
}

output_final_result() {
	if [ "$SFDX_AUTH_URL_CONDENSED" = true ]; then
		echo "$FINAL_JSON" | jq -c .
	elif [ "$JSON_OUTPUT" = true ]; then
		print_json_success "$FINAL_JSON"
	else
		print_human_readable_success
	fi
}

main() {
	parse_args "$@"
	validate_args
	check_dependencies
	run_sf_command
	output_final_result
}

main "$@"
