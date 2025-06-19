#!/bin/bash -x

# -----------------------------------------------------------------------------
# @file scratch-org-create-scratch-from-definition-file.sh
# @brief Create a Salesforce scratch org from a definition file.
#
# This script creates a Salesforce scratch org using a specified definition file,
# duration, Dev Hub alias, and optional namespace. It supports JSON error output.
#
# @usage
#   ./scratch-org-create-scratch-from-definition-file.sh -f <definition-file> -a <alias> -y <duration-days> -v <dev-hub-alias> [-m] [--json]
#   ./scratch-org-create-scratch-from-definition-file.sh --definition-file <definition-file> --alias <alias> --duration-days <duration-days> --target-dev-hub <dev-hub-alias> [--no-namespace] [--json]
#
# @options
#   -f, --definition-file    Path to the scratch org definition file.
#   -a, --alias              Alias for the new scratch org.
#   -y, --duration-days      Duration in days for the scratch org.
#   -v, --target-dev-hub     Alias for the Dev Hub org to use for scratch org creation.
#   -m, --no-namespace       Do not use a namespace.
#   --json                   Output result and errors in JSON format.
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

show_usage() {
	echo "Usage:"
	echo "  $0 -f <definition-file> -a <alias> -y <duration-days> -v <dev-hub-alias> [-m] [--json]"
	echo "  $0 --definition-file <definition-file> --alias <alias> --duration-days <duration-days> --target-dev-hub <dev-hub-alias> [--no-namespace] [--json]"
	echo
	echo "Options:"
	echo "  -f, --definition-file     Path to the scratch org definition file."
	echo "  -a, --alias              Alias for the new scratch org."
	echo "  -y, --duration-days      Duration in days for the scratch org."
	echo "  -v, --target-dev-hub     Alias for the Dev Hub org to use for scratch org creation."
	echo "  -m, --no-namespace       Do not use a namespace."
	echo "  --json                   Output result and errors in JSON format."
	echo "  --help                   Show this help message and exit."
}

parse_args() {
	local args=("$@")
	local DEFINITION_FILE=""
	local SCRATCH_ALIAS=""
	local DURATION_DAYS=""
	local SF_DEV_HUB_ALIAS=""
	local JSON_OUTPUT=false
	local NO_NAMESPACE=false

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

	echo "$DEFINITION_FILE|$SCRATCH_ALIAS|$DURATION_DAYS|$SF_DEV_HUB_ALIAS|$NO_NAMESPACE|$JSON_OUTPUT"
}

validate_args() {
	local DEFINITION_FILE="$1"
	local SCRATCH_ALIAS="$2"
	local DURATION_DAYS="$3"
	local SF_DEV_HUB_ALIAS="$4"
	local JSON_OUTPUT="$5"
	if [ -z "$DEFINITION_FILE" ] || [ -z "$SCRATCH_ALIAS" ] || [ -z "$DURATION_DAYS" ] || [ -z "$SF_DEV_HUB_ALIAS" ]; then
		local msg="Error: definition file, alias, duration days, and dev hub alias must be specified"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "Use -f/--definition-file, -a/--alias, -y/--duration-days, and -v/--target-dev-hub" "MISSING_ARGUMENTS" "${BASH_LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "Use -f/--definition-file, -a/--alias, -y/--duration-days, and -v/--target-dev-hub" "MISSING_ARGUMENTS" "${BASH_LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
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
			print_error_json "$msg" "Install Salesforce CLI to continue." "MISSING_DEPENDENCY" "${BASH_LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "Install Salesforce CLI to continue." "MISSING_DEPENDENCY" "${BASH_LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
	if ! command -v jq > /dev/null 2>&1; then
		local msg="Error: jq is required but not installed."
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "Install jq to continue." "MISSING_DEPENDENCY" "${BASH_LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "Install jq to continue." "MISSING_DEPENDENCY" "${BASH_LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
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
	local CREATE_OUTPUT
	CREATE_OUTPUT=$(run_sf_create_scratch_command "$DEFINITION_FILE" "$SCRATCH_ALIAS" "$DURATION_DAYS" "$SF_DEV_HUB_ALIAS" "$NO_NAMESPACE")
	local status=$?
	if [ $status -ne 0 ] || echo "$CREATE_OUTPUT" | jq -e '.status // empty' | grep -q 1; then
		local msg="Error: Failed to start scratch org creation."
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$CREATE_OUTPUT" "SCRATCH_ORG_CREATION_FAILED" "${BASH_LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$CREATE_OUTPUT" "SCRATCH_ORG_CREATION_FAILED" "${BASH_LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		fi
		return 0
	fi
	echo "$CREATE_OUTPUT"
}

extract_job_id() {
	local CREATE_OUTPUT="$1"
	local JSON_OUTPUT="$2"
	local JOB_ID
	JOB_ID=$(echo "$CREATE_OUTPUT" | jq -r '.result.scratchOrgInfo.Id')
	if [ -z "$JOB_ID" ] || [ "$JOB_ID" = "null" ]; then
		local msg="Error: Could not extract job ID from scratch org creation output."
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$CREATE_OUTPUT" "NO_JOB_ID" "${LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$CREATE_OUTPUT" "NO_JOB_ID" "${LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
	echo "$JOB_ID"
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
	local FINAL_JSON
	if ! FINAL_JSON=$(sf org resume scratch --job-id "$JOB_ID" --json 2> /dev/null); then
		# If resume fails, try to use CREATE_OUTPUT if it's valid JSON
		if echo "$CREATE_OUTPUT" | jq empty 2> /dev/null; then
			FINAL_JSON="$CREATE_OUTPUT"
		else
			local msg="Neither resume nor CREATE_OUTPUT returned valid JSON."
			local func="${FUNCNAME[0]}"
			if [ "$JSON_OUTPUT" = true ]; then
				print_error_json "$msg" "$CREATE_OUTPUT" "INVALID_JSON" "${BASH_LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
			else
				print_error_block "$msg" "$CREATE_OUTPUT" "INVALID_JSON" "${BASH_LINENO[0]}" "${BASH_SOURCE[0]}" "$func"
			fi
			exit 1
		fi
	fi
	echo "$FINAL_JSON"
}

output_final_result() {
	local FINAL_JSON="$1"
	local JSON_OUTPUT="$2"
	if [ "$JSON_OUTPUT" = true ]; then
		print_standard_json "OK" "Scratch org created successfully." "$FINAL_JSON"
	else
		print_standard_block "OK" "Scratch org created successfully!" "$FINAL_JSON"
	fi
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
	JOB_ID=$(extract_job_id "$CREATE_OUTPUT" "$JSON_OUTPUT")
	show_progress "$JOB_ID"
	FINAL_JSON=$(get_final_json_output "$JOB_ID" "$CREATE_OUTPUT" "$JSON_OUTPUT")
	output_final_result "$FINAL_JSON" "$JSON_OUTPUT"
}

main() {
	local parsed
	parsed=$(parse_args "$@")
	IFS='|' read -r DEFINITION_FILE SCRATCH_ALIAS DURATION_DAYS SF_DEV_HUB_ALIAS NO_NAMESPACE JSON_OUTPUT <<< "$parsed"
	validate_args "$DEFINITION_FILE" "$SCRATCH_ALIAS" "$DURATION_DAYS" "$SF_DEV_HUB_ALIAS" "$JSON_OUTPUT"
	check_dependencies "$JSON_OUTPUT"
	run_scratch_org_creation "$DEFINITION_FILE" "$SCRATCH_ALIAS" "$DURATION_DAYS" "$SF_DEV_HUB_ALIAS" "$NO_NAMESPACE" "$JSON_OUTPUT"
}

main "$@"
