#!/bin/bash

# -----------------------------------------------------------------------------
# @file <script-name>.sh
# @brief <Short description of what this script does>
#
# @description
#   <Longer description of the script's purpose and behavior.>
#
# @usage
#   ./<script-name>.sh [options]
#
# @options
#   -x, --example         Example argument description.
#   --json                Output result and errors in JSON format.
#   -h, --help            Show this help message and exit.
#
# @exitcodes
#   0  Success
#   1  Missing required arguments, invalid usage, or error during execution
# -----------------------------------------------------------------------------

set -euo pipefail

# Get the directory of the current script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/output-utils.sh"

# Default values for arguments
EXAMPLE_ARG=""
JSON_OUTPUT=false

show_usage() {
	echo "Usage:"
	echo "  $0 -x <example> [--json]"
	echo
	echo "Options:"
	echo "  -x, --example         Example argument description."
	echo "  --json                Output result and errors in JSON format."
	echo "  -h, --help            Show this help message and exit."
}

parse_args() {
	EXAMPLE_ARG=""
	JSON_OUTPUT=false
	while [[ $# -gt 0 ]]; do
		case "$1" in
			-x | --example)
				EXAMPLE_ARG="$2"
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
				show_usage >&2
				exit 1
				;;
		esac
	done
}

check_dependencies() {
	# Example: check for jq and sf
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
	# Add more dependency checks as needed
}

validate_args() {
	if [ -z "$EXAMPLE_ARG" ]; then
		local msg="Error: example argument must be specified with -x/--example"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "Use -x/--example" "MISSING_ARGUMENTS" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "Use -x/--example" "MISSING_ARGUMENTS" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
}

main_logic() {
	# Replace this with your main script logic
	local RESULT_JSON='{"result":"success"}'
	local SUCCESS_STATUS="OK"
	local message="Operation completed successfully."
	local detail="$RESULT_JSON"

	if [ "$JSON_OUTPUT" = true ]; then
		print_standard_json "$SUCCESS_STATUS" "$message" "$detail"
	else
		print_standard_block "$SUCCESS_STATUS" "$message" "$detail"
	fi
}

main() {
	if [ $# -eq 0 ]; then
		show_usage
		exit 1
	fi
	parse_args "$@"
	validate_args
	check_dependencies
	main_logic
}

main "$@"
