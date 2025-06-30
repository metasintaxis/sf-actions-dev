#!/bin/bash

# -----------------------------------------------------------------------------
# @file create-tasks.sh
# @brief Create TaskWarrior tasks from GitHub issues
#
# @description
#   This script fetches issues from a GitHub repository using fetch-issues.sh
#   and generates a TaskWarrior script file with task add commands. Each issue
#   becomes a task with the format: task add tag:REPO project:GH-NUMBER TITLE
#
# @usage
#   ./create-tasks.sh -r <repo> [--output <file>] [--tag <tag>] [--state <state>] [--exclude-labels <labels>] [--dry-run] [--json] [--log FILE] [--debug [LEVEL]]
#   ./create-tasks.sh -r owner/repo-name --output tasks.sh [--json] [--log FILE] [--debug [LEVEL]]
#
# @options
#   -r, --repo REPO       GitHub repository in format owner/repo-name (required).
#   --output FILE         Output file for TaskWarrior commands (default: tasks-REPO.sh).
#   --tag TAG             Tag to add to all tasks (default: extracted from repo name).
#   --state STATE         Issue state: open, closed, all (default: open).
#   --exclude-labels LABELS  Comma-separated list of labels to exclude (default: "help wanted,wontfix").
#   --dry-run             Show what would be generated without creating the file.
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
OUTPUT_FILE=""
TAG=""
STATE="open"
EXCLUDE_LABELS="help wanted,wontfix"
DRY_RUN=false
JSON_OUTPUT=false
DEBUG_LEVEL=""
LOG_FILE=""

# Path to the fetch-issues script
FETCH_ISSUES_SCRIPT="${SCRIPT_DIR}/fetch-issues.sh"

show_usage() {
	echo "Usage:"
	echo "  $0 -r <repo> [--output <file>] [--tag <tag>] [--state <state>] [--exclude-labels <labels>] [--dry-run] [--json] [--log FILE] [--debug [LEVEL]]"
	echo
	echo "Options:"
	echo "  -r, --repo REPO         GitHub repository in format owner/repo-name (required)."
	echo "  --output FILE           Output file for TaskWarrior commands (default: tasks-REPO.sh)."
	echo "  --tag TAG               Tag to add to all tasks (default: extracted from repo name)."
	echo "  --state STATE           Issue state: open, closed, all (default: open)."
	echo "  --exclude-labels LABELS Comma-separated list of labels to exclude (default: \"help wanted,wontfix\")."
	echo "  --dry-run               Show what would be generated without creating the file."
	echo "  --json                  Output result and errors in JSON format."
	echo "  --log FILE              Write debug and operational logs to specified file"
	echo "  --debug [LEVEL]         Enable debug logging to stderr. Optional LEVEL:"
	echo "                          DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY"
	echo "                          (default: DEBUG if no level specified)"
	echo "  -h, --help              Show this help message and exit."
	echo
	echo "Description:"
	echo "  This script fetches issues from a GitHub repository and generates"
	echo "  TaskWarrior task add commands in the format:"
	echo "  task add tag:TAG project:GH-NUMBER TITLE"
	echo
	echo "Examples:"
	echo "  $0 -r metasintaxis/sf-actions-dev"
	echo "  $0 -r owner/repo --output my-tasks.sh --tag myproject --state all"
	echo "  $0 -r owner/repo --exclude-labels \"wontfix,duplicate\" --dry-run"
}

parse_args() {
	REPO=""
	OUTPUT_FILE=""
	TAG=""
	STATE="open"
	EXCLUDE_LABELS="help wanted,wontfix"
	DRY_RUN=false
	JSON_OUTPUT=false
	DEBUG_LEVEL=""
	LOG_FILE=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
			-r | --repo)
				REPO="$2"
				shift 2
				;;
			--output)
				OUTPUT_FILE="$2"
				shift 2
				;;
			--tag)
				TAG="$2"
				shift 2
				;;
			--state)
				STATE="$2"
				shift 2
				;;
			--exclude-labels)
				EXCLUDE_LABELS="$2"
				shift 2
				;;
			--dry-run)
				DRY_RUN=true
				shift
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

	# Check for fetch-issues.sh script
	if [ ! -f "$FETCH_ISSUES_SCRIPT" ]; then
		log_error_stderr "Missing dependency: fetch-issues.sh script not found"
		local msg="Error: fetch-issues.sh script is required but not found."
		local detail="Expected location: $FETCH_ISSUES_SCRIPT"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "MISSING_SCRIPT" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "MISSING_SCRIPT" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
	log_debug_stderr "fetch-issues.sh script found"
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

	# Validate state
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

	# Set default values if not provided
	if [ -z "$TAG" ]; then
		# Extract tag from repository name (use the repo name part)
		TAG=$(echo "$REPO" | cut -d'/' -f2)
		log_debug_stderr "Using default tag from repo name: $TAG"
	fi

	if [ -z "$OUTPUT_FILE" ]; then
		# Generate default output filename
		local repo_name=$(echo "$REPO" | cut -d'/' -f2)
		OUTPUT_FILE="tasks-${repo_name}.sh"
		log_debug_stderr "Using default output file: $OUTPUT_FILE"
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

# Function to sanitize title for TaskWarrior command
sanitize_title() {
	local title="$1"
	# Remove or escape characters that might cause issues in shell commands
	echo "$title" | sed 's/"/\\"/g' | sed "s/'/\\'/g"
}

# Function to generate TaskWarrior command for an issue
generate_task_command() {
	local issue_number="$1"
	local issue_title="$2"
	local sanitized_title
	
	sanitized_title=$(sanitize_title "$issue_title")
	echo "task add tag:$TAG project:GH-$issue_number $sanitized_title"
}

create_tasks() {
	log_info_stderr "Creating TaskWarrior tasks from GitHub issues"
	log_debug_stderr "Repository: $REPO, State: $STATE, Tag: $TAG, Output: $OUTPUT_FILE, Exclude labels: '$EXCLUDE_LABELS', Dry run: $DRY_RUN"

	# Fetch issues using the fetch-issues script
	log_debug_stderr "Fetching issues from $REPO"
	local fetch_args=(
		"-r" "$REPO"
		"--state" "$STATE"
		"--json"
	)

	# Add exclude labels if specified
	if [ -n "$EXCLUDE_LABELS" ]; then
		fetch_args+=("--exclude-labels" "$EXCLUDE_LABELS")
	fi

	# Add debug flag if present
	if [ -n "$DEBUG_LEVEL" ]; then
		fetch_args+=("--debug" "$DEBUG_LEVEL")
	fi

	# Add log file if present
	if [ -n "$LOG_FILE" ]; then
		fetch_args+=("--log" "$LOG_FILE")
	fi

	local issues_response
	if ! issues_response=$("$FETCH_ISSUES_SCRIPT" "${fetch_args[@]}"); then
		log_error_stderr "Failed to fetch issues"
		local msg="Error: Failed to fetch issues"
		local detail="The fetch-issues script failed to retrieve issues from $REPO"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "FETCH_FAILED" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "FETCH_FAILED" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi

	# Extract the issues array from the response
	local issues_json
	if ! issues_json=$(echo "$issues_response" | jq -r '.detail' 2> /dev/null); then
		log_error_stderr "Failed to parse issues response"
		local msg="Error: Invalid response format from fetch-issues script"
		local detail="Could not extract issues data from the response"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "PARSE_ERROR" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "PARSE_ERROR" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi

	# Count total issues
	local total_issues
	if ! total_issues=$(echo "$issues_json" | jq length 2> /dev/null); then
		log_error_stderr "Failed to count issues"
		local msg="Error: Could not count issues"
		local detail="Issues data is not in expected array format"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "COUNT_ERROR" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "COUNT_ERROR" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi

	log_info_stderr "Found $total_issues issues to process"

	if [ "$total_issues" -eq 0 ]; then
		local msg="No issues found"
		local detail="No issues found in repository $REPO with the specified criteria"
		if [ "$JSON_OUTPUT" = true ]; then
			print_standard_json "OK" "$msg" "$detail"
		else
			print_standard_block "OK" "$msg" "$detail"
		fi
		return 0
	fi

	# Generate TaskWarrior commands
	local task_commands=()
	while IFS=$'\t' read -r issue_number issue_title; do
		local task_cmd
		task_cmd=$(generate_task_command "$issue_number" "$issue_title")
		task_commands+=("$task_cmd")
		log_debug_stderr "Generated task command for issue #$issue_number: $task_cmd"
	done < <(echo "$issues_json" | jq -r '.[] | [.number, .title] | @tsv')

	# Generate output content
	local output_content="#!/bin/bash\n\n"
	for cmd in "${task_commands[@]}"; do
		output_content="${output_content}${cmd}\n"
	done

	if [ "$DRY_RUN" = true ]; then
		echo "Would create file: $OUTPUT_FILE"
		echo "Content:"
		echo -e "$output_content"
		
		local msg="Dry run completed: would create $total_issues task commands"
		local detail="Output file: $OUTPUT_FILE"
	else
		# Write to output file
		if echo -e "$output_content" > "$OUTPUT_FILE"; then
			chmod +x "$OUTPUT_FILE"
			log_info_stderr "Successfully created TaskWarrior script: $OUTPUT_FILE"
			
			local msg="Successfully created TaskWarrior script with $total_issues tasks"
			local detail="Output file: $OUTPUT_FILE"
		else
			log_error_stderr "Failed to write output file: $OUTPUT_FILE"
			local msg="Error: Failed to write output file"
			local detail="Could not write to $OUTPUT_FILE. Check permissions."
			local func="${FUNCNAME[0]}"
			if [ "$JSON_OUTPUT" = true ]; then
				print_error_json "$msg" "$detail" "WRITE_ERROR" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
			else
				print_error_block "$msg" "$detail" "WRITE_ERROR" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
			fi
			exit 1
		fi
	fi

	# Prepare summary JSON
	local summary_json
	local exclude_labels_json
	if [ -n "$EXCLUDE_LABELS" ]; then
		exclude_labels_json=$(echo "$EXCLUDE_LABELS" | tr ',' '\n' | jq -R . | jq -s .)
	else
		exclude_labels_json="[]"
	fi
	
	summary_json=$(jq -n \
		--arg repo "$REPO" \
		--arg state "$STATE" \
		--arg tag "$TAG" \
		--arg output_file "$OUTPUT_FILE" \
		--argjson exclude_labels "$exclude_labels_json" \
		--argjson total_issues "$total_issues" \
		--argjson dry_run "$DRY_RUN" \
		--argjson task_commands "$(printf '%s\n' "${task_commands[@]}" | jq -R . | jq -s .)" \
		'{
			repository: $repo,
			state: $state,
			tag: $tag,
			output_file: $output_file,
			exclude_labels: $exclude_labels,
			dry_run: $dry_run,
			summary: {
				total_issues: $total_issues,
				tasks_generated: $total_issues
			},
			task_commands: $task_commands
		}')

	local success_status="OK"
	log_debug_stderr "Preparing output in requested format"
	if [ "$JSON_OUTPUT" = true ]; then
		log_debug_stderr "Outputting structured JSON format"
		print_standard_json "$success_status" "$msg" "$summary_json"
	else
		log_debug_stderr "Outputting human-readable format"
		print_standard_block "$success_status" "$msg" "$detail"
	fi

	log_info_stderr "TaskWarrior script creation completed"
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
	log_info_stderr "Parsed arguments - Repository: '$REPO', JSON output: $JSON_OUTPUT, Debug level: ${DEBUG_LEVEL:-NONE}, Log file: ${LOG_FILE:-NONE}"

	validate_args
	log_debug_stderr "Argument validation completed successfully"

	check_dependencies
	log_debug_stderr "Dependency checks completed successfully"

	create_tasks
	log_debug_stderr "Script execution completed successfully"
}

main "$@"
