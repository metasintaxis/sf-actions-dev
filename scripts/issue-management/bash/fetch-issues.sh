#!/bin/bash

# -----------------------------------------------------------------------------
# @file fetch-active-issues.sh
# @brief Fetch open issues from a GitHub repository using GitHub CLI
#
# @description
#   This script retrieves open issues from a specified GitHub repository using
#   the GitHub CLI (gh). It supports filtering by various criteria and outputs
#   results in both human-readable and JSON formats following the CLI Output
#   Specification.
#
# @usage
#   ./fetch-active-issues.sh -r <repo> [--state <state>] [--assignee <user>] [--labels <labels>] [--exclude-labels <labels>] [--limit <num>] [--json] [--log FILE] [--debug [LEVEL]]
#   ./fetch-active-issues.sh -r <repo> --issue <number> [--json] [--log FILE] [--debug [LEVEL]]
#   ./fetch-active-issues.sh -r owner/repo-name [--json] [--log FILE] [--debug [LEVEL]]
#
# @options
#   -r, --repo REPO       GitHub repository in format owner/repo-name (required).
#   -i, --issue NUMBER    Fetch specific issue by number.
#   --state STATE         Issue state: open, closed, all (default: open). Ignored when --issue is specified.
#   --assignee USER       Filter by assignee username. Ignored when --issue is specified.
#   --labels LABELS       Filter by labels (comma-separated). Ignored when --issue is specified.
#   --exclude-labels LABELS  Exclude issues with any of these labels (comma-separated). Ignored when --issue is specified.
#   --limit NUM           Maximum number of issues to fetch (default: 30). Ignored when --issue is specified.
#   --json                Output result and errors in JSON format.
#   --log FILE            Write debug and operational logs to specified file
#   --debug [LEVEL]       Enable debug logging to stderr. Optional LEVEL:
#                         DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY
#                         (default: DEBUG if no level specified)
#   -h, --help            Show this help message and exit.
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
REPO=""
ISSUE_NUMBER=""
STATE="open"
ASSIGNEE=""
LABELS=""
EXCLUDE_LABELS=""
LIMIT="30"
JSON_OUTPUT=false
DEBUG_LEVEL=""
LOG_FILE=""

show_usage() {
	echo "Usage:"
	echo "  $0 -r <repo> [--state <state>] [--assignee <user>] [--labels <labels>] [--exclude-labels <labels>] [--limit <num>] [--json] [--log FILE] [--debug [LEVEL]]"
	echo "  $0 -r <repo> --issue <number> [--json] [--log FILE] [--debug [LEVEL]]"
	echo
	echo "Options:"
	echo "  -r, --repo REPO       GitHub repository in format owner/repo-name (required)."
	echo "  -i, --issue NUMBER    Fetch specific issue by number."
	echo "  --state STATE         Issue state: open, closed, all (default: open). Ignored when --issue is specified."
	echo "  --assignee USER       Filter by assignee username. Ignored when --issue is specified."
	echo "  --labels LABELS       Filter by labels (comma-separated). Ignored when --issue is specified."
	echo "  --exclude-labels LABELS  Exclude issues with any of these labels (comma-separated). Ignored when --issue is specified."
	echo "  --limit NUM           Maximum number of issues to fetch (default: 30). Ignored when --issue is specified."
	echo "  --json                Output result and errors in JSON format."
	echo "  --log FILE            Write debug and operational logs to specified file"
	echo "  --debug [LEVEL]       Enable debug logging to stderr. Optional LEVEL:"
	echo "                        DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY"
	echo "                        (default: DEBUG if no level specified)"
	echo "  -h, --help            Show this help message and exit."
	echo
	echo "Description:"
	echo "  This script fetches issues from the specified GitHub repository."
	echo "  When --issue is specified, only that specific issue will be fetched,"
	echo "  and all other filter options (state, assignee, labels, etc.) will be ignored."
	echo "  When --issue is not specified, all issues matching the specified filters"
	echo "  will be fetched."
	echo
	echo "Examples:"
	echo "  $0 -r metasintaxis/sf-actions-dev"
	echo "  $0 -r owner/repo --state all --assignee username --json"
	echo "  $0 -r owner/repo --labels bug,enhancement --limit 50"
	echo "  $0 -r owner/repo --exclude-labels 'help wanted,wontfix'"
	echo "  $0 -r owner/repo --issue 42 --json"
}

parse_args() {
	REPO=""
	ISSUE_NUMBER=""
	STATE="open"
	ASSIGNEE=""
	LABELS=""
	EXCLUDE_LABELS=""
	LIMIT="30"
	JSON_OUTPUT=false
	DEBUG_LEVEL=""
	LOG_FILE=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
			-r | --repo)
				REPO="$2"
				shift 2
				;;
			-i | --issue)
				ISSUE_NUMBER="$2"
				shift 2
				;;
			--state)
				STATE="$2"
				shift 2
				;;
			--assignee)
				ASSIGNEE="$2"
				shift 2
				;;
			--labels)
				LABELS="$2"
				shift 2
				;;
			--exclude-labels)
				EXCLUDE_LABELS="$2"
				shift 2
				;;
			--limit)
				LIMIT="$2"
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

	# Check for gh (GitHub CLI)
	if ! command -v gh > /dev/null 2>&1; then
		log_error_stderr "Missing dependency: gh (GitHub CLI) is not installed"
		local msg="Error: GitHub CLI (gh) is required but not installed."
		local detail="Install GitHub CLI from https://cli.github.com/ to continue."
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "MISSING_DEPENDENCY" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "MISSING_DEPENDENCY" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
	log_debug_stderr "GitHub CLI dependency check passed"

	# Check for jq
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

	# Check GitHub CLI authentication
	if ! gh auth status > /dev/null 2>&1; then
		log_error_stderr "GitHub CLI authentication required"
		local msg="Error: GitHub CLI is not authenticated."
		local detail="Run 'gh auth login' to authenticate with GitHub."
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "AUTH_REQUIRED" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "AUTH_REQUIRED" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
	log_debug_stderr "GitHub CLI authentication check passed"
}

validate_args() {
	log_debug_stderr "Validating required arguments"

	if [ -z "$REPO" ]; then
		log_error_stderr "Missing required argument: repository not specified"
		local msg="Error: repository must be specified with -r/--repo"
		local detail="Use -r/--repo in format owner/repo-name (e.g., metasintaxis/sf-actions-dev)"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "MISSING_ARGUMENTS" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "MISSING_ARGUMENTS" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi

	# Validate repository format (owner/repo)
	if [[ ! "$REPO" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
		log_error_stderr "Invalid repository format: $REPO"
		local msg="Error: repository format is invalid"
		local detail="Repository must be in format owner/repo-name (e.g., metasintaxis/sf-actions-dev)"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "INVALID_FORMAT" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "INVALID_FORMAT" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi

	# Validate issue number if provided
	if [ -n "$ISSUE_NUMBER" ]; then
		if [[ ! "$ISSUE_NUMBER" =~ ^[0-9]+$ ]]; then
			log_error_stderr "Invalid issue number: $ISSUE_NUMBER"
			local msg="Error: issue number must be a positive integer"
			local detail="Issue number provided: '$ISSUE_NUMBER'"
			local func="${FUNCNAME[0]}"
			if [ "$JSON_OUTPUT" = true ]; then
				print_error_json "$msg" "$detail" "INVALID_ISSUE_NUMBER" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
			else
				print_error_block "$msg" "$detail" "INVALID_ISSUE_NUMBER" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
			fi
			exit 1
		fi
		log_debug_stderr "Specific issue mode: will fetch issue #$ISSUE_NUMBER (other filters ignored)"
		return 0
	fi

	# Validate state (only when not fetching specific issue)
	if [[ ! "$STATE" =~ ^(open|closed|all)$ ]]; then
		log_error_stderr "Invalid state: $STATE"
		local msg="Error: invalid state specified"
		local detail="State must be one of: open, closed, all"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "INVALID_STATE" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "INVALID_STATE" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi

	# Validate limit is a positive integer (only when not fetching specific issue)
	if ! [[ "$LIMIT" =~ ^[1-9][0-9]*$ ]]; then
		log_error_stderr "Invalid limit: $LIMIT"
		local msg="Error: limit must be a positive integer"
		local detail="Limit must be a number greater than 0"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "INVALID_LIMIT" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "INVALID_LIMIT" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi

	log_debug_stderr "All required arguments are valid"
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

# Function to fetch a specific issue by number
fetch_specific_issue() {
	local issue_number="$1"
	log_debug_stderr "Fetching specific issue #$issue_number from $REPO"

	local gh_cmd="gh issue view $issue_number --repo $REPO --json number,title,state,author,createdAt,updatedAt,labels,assignees,url"

	log_debug_stderr "Executing GitHub CLI command: $gh_cmd"
	local issue_json
	if ! issue_json=$(eval "$gh_cmd" 2> /dev/null); then
		log_error_stderr "Failed to fetch issue #$issue_number from GitHub"
		return 1
	fi

	echo "$issue_json"
}

build_gh_command() {
	log_debug_stderr "Building GitHub CLI command"

	local gh_cmd="gh issue list --repo $REPO --state $STATE --limit $LIMIT"

	# Add optional filters
	if [ -n "$ASSIGNEE" ]; then
		gh_cmd="$gh_cmd --assignee $ASSIGNEE"
		log_debug_stderr "Added assignee filter: $ASSIGNEE"
	fi

	if [ -n "$LABELS" ]; then
		gh_cmd="$gh_cmd --label $LABELS"
		log_debug_stderr "Added labels filter: $LABELS"
	fi

	# Add JSON output for data extraction
	gh_cmd="$gh_cmd --json number,title,state,author,createdAt,updatedAt,labels,assignees,url"

	log_debug_stderr "Final GitHub CLI command: $gh_cmd"
	echo "$gh_cmd"
}

fetch-issues() {
	if [ -n "$ISSUE_NUMBER" ]; then
		log_info_stderr "Fetching specific issue #$ISSUE_NUMBER from repository: $REPO"
		log_debug_stderr "Specific issue mode - other filters are ignored"

		# Fetch specific issue
		local issue_json
		if ! issue_json=$(fetch_specific_issue "$ISSUE_NUMBER"); then
			local msg="Error: Failed to fetch issue #$ISSUE_NUMBER"
			local detail="The issue may not exist or may not be accessible in repository $REPO"
			local func="${FUNCNAME[0]}"
			if [ "$JSON_OUTPUT" = true ]; then
				print_error_json "$msg" "$detail" "ISSUE_NOT_FOUND" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
			else
				print_error_block "$msg" "$detail" "ISSUE_NOT_FOUND" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
			fi
			exit 1
		fi

		log_info_stderr "Successfully fetched issue #$ISSUE_NUMBER"

		# Prepare output
		local success_status="OK"
		local message="Successfully fetched issue #$ISSUE_NUMBER from $REPO"
		local detail="$issue_json"

		log_debug_stderr "Preparing output in requested format"
		if [ "$JSON_OUTPUT" = true ]; then
			log_debug_stderr "Outputting structured JSON format"
			print_standard_json "$success_status" "$message" "$detail"
		else
			log_debug_stderr "Outputting human-readable format"
			print_standard_block "$success_status" "$message" "$detail"
		fi

		log_info_stderr "Issue fetched successfully"
		return 0
	fi

	# Original logic for fetching multiple issues
	log_info_stderr "Fetching GitHub issues from repository: $REPO"
	log_debug_stderr "Parameters - State: $STATE, Assignee: ${ASSIGNEE:-none}, Labels: ${LABELS:-none}, Exclude Labels: ${EXCLUDE_LABELS:-none}, Limit: $LIMIT"

	# Build and execute GitHub CLI command
	local gh_command
	gh_command=$(build_gh_command)

	log_debug_stderr "Executing GitHub CLI command"
	local all_issues_json
	if ! all_issues_json=$(eval "$gh_command" 2> /dev/null); then
		log_error_stderr "Failed to fetch issues from GitHub"
		local msg="Error: Failed to fetch issues from repository"
		local detail="Could not retrieve issues from $REPO. Check repository name and permissions."
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "FETCH_FAILED" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "FETCH_FAILED" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi

	# Apply exclude labels filtering if specified
	local issues_json="$all_issues_json"
	local total_fetched
	local total_after_filter

	if ! total_fetched=$(echo "$all_issues_json" | jq length 2> /dev/null); then
		log_error_stderr "Failed to parse GitHub CLI response"
		local msg="Error: Invalid response from GitHub CLI"
		local detail="Could not parse JSON response from GitHub CLI"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "PARSE_ERROR" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "PARSE_ERROR" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi

	if [ -n "$EXCLUDE_LABELS" ]; then
		log_debug_stderr "Applying exclude labels filter: $EXCLUDE_LABELS"

		# Convert comma-separated exclude labels to jq array format
		local exclude_labels_array
		exclude_labels_array=$(echo "$EXCLUDE_LABELS" | sed 's/,/","/g' | sed 's/^/"/' | sed 's/$/"/')

		# Filter out issues that have any of the excluded labels
		if ! issues_json=$(echo "$all_issues_json" | jq --argjson exclude_labels "[$exclude_labels_array]" '[.[] | select((.labels | map(.name) | any(. as $label | $exclude_labels | index($label))) | not)]' 2> /dev/null); then
			log_error_stderr "Failed to apply exclude labels filter"
			local msg="Error: Failed to filter issues by excluded labels"
			local detail="Could not filter out issues with labels: $EXCLUDE_LABELS"
			local func="${FUNCNAME[0]}"
			if [ "$JSON_OUTPUT" = true ]; then
				print_error_json "$msg" "$detail" "FILTER_ERROR" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
			else
				print_error_block "$msg" "$detail" "FILTER_ERROR" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
			fi
			exit 1
		fi

		if ! total_after_filter=$(echo "$issues_json" | jq length 2> /dev/null); then
			log_error_stderr "Failed to count filtered issues"
			exit 1
		fi

		local filtered_count=$((total_fetched - total_after_filter))
		log_info_stderr "Fetched $total_fetched issues, filtered out $filtered_count with excluded labels, returning $total_after_filter issues"
	else
		total_after_filter="$total_fetched"
		log_info_stderr "Successfully fetched $total_after_filter issues"
	fi

	# Prepare output
	local success_status="OK"
	local message
	if [ -n "$EXCLUDE_LABELS" ]; then
		local filtered_count=$((total_fetched - total_after_filter))
		message="Successfully fetched $total_fetched issues from $REPO, filtered out $filtered_count with excluded labels, returning $total_after_filter issues"
	else
		message="Successfully fetched $total_after_filter issues from $REPO"
	fi
	local detail="$issues_json"

	log_debug_stderr "Preparing output in requested format"
	if [ "$JSON_OUTPUT" = true ]; then
		log_debug_stderr "Outputting structured JSON format"
		print_standard_json "$success_status" "$message" "$detail"
	else
		log_debug_stderr "Outputting human-readable format"
		print_standard_block "$success_status" "$message" "$detail"
	fi

	log_info_stderr "Issues fetched successfully"
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
	if [ -n "$ISSUE_NUMBER" ]; then
		log_info_stderr "Parsed arguments - Repo: '$REPO', Issue: '$ISSUE_NUMBER', JSON output: $JSON_OUTPUT, Debug level: ${DEBUG_LEVEL:-NONE}, Log file: ${LOG_FILE:-NONE}"
	else
		log_info_stderr "Parsed arguments - Repo: '$REPO', State: '$STATE', Assignee: '${ASSIGNEE:-none}', Labels: '${LABELS:-none}', Exclude Labels: '${EXCLUDE_LABELS:-none}', Limit: '$LIMIT', JSON output: $JSON_OUTPUT, Debug level: ${DEBUG_LEVEL:-NONE}, Log file: ${LOG_FILE:-NONE}"
	fi

	validate_args
	log_debug_stderr "Argument validation completed successfully"

	check_dependencies
	log_debug_stderr "Dependency checks completed successfully"

	fetch-issues
	log_debug_stderr "Script execution completed successfully"
}

main "$@"
