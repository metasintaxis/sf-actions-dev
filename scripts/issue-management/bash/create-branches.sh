#!/bin/bash

# -----------------------------------------------------------------------------
# @file create-branches.sh
# @brief Create Git branches from open GitHub issues
#
# @description
#   This script fetches open issues from a GitHub repository and creates corresponding
#   Git branches from a base branch (default: dev). Issues with specified exclude labels
#   can be filtered out. Each branch follows the naming convention:
#   GH-[ISSUE_NUMBER]-Issue-Title. The script uses the fetch-issues.sh script as a dependency.
#
# @usage
#   ./create-branches.sh -r <repo> [--base-branch <branch>] [--exclude-labels <labels>] [--dry-run] [--json] [--log FILE] [--debug [LEVEL]]
#   ./create-branches.sh -r owner/repo-name [--exclude-labels "help wanted,wontfix"] [--json] [--log FILE] [--debug [LEVEL]]
#
# @options
#   -r, --repo REPO       GitHub repository in format owner/repo-name (required).
#   --base-branch BRANCH  Base branch to create new branches from (default: dev).
#   --exclude-labels LABELS  Comma-separated list of labels to exclude (default: "help wanted,wontfix").
#   --dry-run             Show what branches would be created without actually creating them.
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
BASE_BRANCH="dev"
EXCLUDE_LABELS="help wanted,wontfix"
DRY_RUN=false
JSON_OUTPUT=false
DEBUG_LEVEL=""
LOG_FILE=""

# Path to the fetch-issues script
FETCH_ISSUES_SCRIPT="${SCRIPT_DIR}/fetch-issues.sh"

show_usage() {
	echo "Usage:"
	echo "  $0 -r <repo> [--base-branch <branch>] [--exclude-labels <labels>] [--dry-run] [--json] [--log FILE] [--debug [LEVEL]]"
	echo
	echo "Options:"
	echo "  -r, --repo REPO         GitHub repository in format owner/repo-name (required)."
	echo "  --base-branch BRANCH    Base branch to create new branches from (default: dev)."
	echo "  --exclude-labels LABELS Comma-separated list of labels to exclude (default: \"help wanted,wontfix\")."
	echo "  --dry-run               Show what branches would be created without actually creating them."
	echo "  --json                  Output result and errors in JSON format."
	echo "  --log FILE              Write debug and operational logs to specified file"
	echo "  --debug [LEVEL]         Enable debug logging to stderr. Optional LEVEL:"
	echo "                          DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY"
	echo "                          (default: DEBUG if no level specified)"
	echo "  -h, --help              Show this help message and exit."
	echo
	echo "Description:"
	echo "  This script fetches open issues from the specified GitHub repository"
	echo "  (excluding those with specified exclude labels) and creates"
	echo "  corresponding Git branches with the format:"
	echo "  GH-[ISSUE_NUMBER]-Issue-Title"
	echo
	echo "Examples:"
	echo "  $0 -r metasintaxis/sf-actions-dev"
	echo "  $0 -r owner/repo --base-branch main --exclude-labels \"wontfix,duplicate\" --dry-run"
	echo "  $0 -r owner/repo --exclude-labels \"\" --json --debug INFO  # No exclusions"
}

parse_args() {
	REPO=""
	BASE_BRANCH="dev"
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
			--base-branch)
				BASE_BRANCH="$2"
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

	# Check for Git
	if ! command -v git > /dev/null 2>&1; then
		log_error_stderr "Missing dependency: git is not installed"
		local msg="Error: Git is required but not installed."
		local detail="Install Git to continue."
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "MISSING_DEPENDENCY" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "MISSING_DEPENDENCY" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
	log_debug_stderr "Git dependency check passed"

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

	# Check if we're in a Git repository
	if ! git rev-parse --git-dir > /dev/null 2>&1; then
		log_error_stderr "Not in a Git repository"
		local msg="Error: Current directory is not a Git repository."
		local detail="Navigate to a Git repository or initialize one with 'git init'"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "NOT_GIT_REPO" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "NOT_GIT_REPO" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
	log_debug_stderr "Git repository check passed"
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

	# Validate base branch name (basic validation)
	if [[ ! "$BASE_BRANCH" =~ ^[a-zA-Z0-9_/-]+$ ]]; then
		log_error_stderr "Invalid base branch name: $BASE_BRANCH"
		local msg="Error: base branch name contains invalid characters"
		local detail="Branch name should contain only alphanumeric characters, underscores, hyphens, and forward slashes"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "INVALID_BRANCH" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "INVALID_BRANCH" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
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

# Function to sanitize issue title for branch name
sanitize_branch_name() {
	local title="$1"
	# Convert to lowercase, remove problematic characters, replace spaces with hyphens, clean up multiple hyphens
	echo "$title" \
		| tr '[:upper:]' '[:lower:]' \
		| sed 's/[^a-z0-9 ]//g' \
		| tr ' ' '-' \
		| sed 's/-\+/-/g' \
		| sed 's/^-\|-$//g'
}

# Function to build jq filter for excluding labels
build_exclude_filter() {
	local exclude_labels="$1"

	# If no exclude labels, return a filter that includes all issues
	if [ -z "$exclude_labels" ]; then
		echo "."
		return 0
	fi

	# Parse comma-separated labels and build jq conditions
	local conditions=()
	local IFS=','
	read -ra labels_array <<< "$exclude_labels"

	for label in "${labels_array[@]}"; do
		# Trim whitespace
		label=$(echo "$label" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
		if [ -n "$label" ]; then
			conditions+=("\"$label\"")
		fi
	done

	# If no valid labels after parsing, return filter that includes all
	if [ ${#conditions[@]} -eq 0 ]; then
		echo "."
		return 0
	fi

	# Build the jq filter: select issues that don't have any of the exclude labels
	local condition_string
	condition_string=$(
		IFS=' or . == '
		echo "${conditions[*]}"
	)
	echo "[.[] | select((.labels | map(.name) | any(. == $condition_string)) | not)]"
}

# Function to check if base branch exists and is available
check_base_branch() {
	log_debug_stderr "Checking if base branch '$BASE_BRANCH' exists"

	# Check if branch exists locally
	if git show-ref --verify --quiet "refs/heads/$BASE_BRANCH"; then
		log_debug_stderr "Base branch '$BASE_BRANCH' exists locally"
		return 0
	fi

	# Check if branch exists on remote
	if git show-ref --verify --quiet "refs/remotes/origin/$BASE_BRANCH"; then
		log_debug_stderr "Base branch '$BASE_BRANCH' exists on remote, will checkout"
		if ! git checkout -b "$BASE_BRANCH" "origin/$BASE_BRANCH" 2> /dev/null; then
			log_error_stderr "Failed to checkout base branch from remote"
			return 1
		fi
		return 0
	fi

	log_error_stderr "Base branch '$BASE_BRANCH' not found locally or on remote"
	return 1
}

# Function to create a branch for an issue
create_branch_for_issue() {
	local issue_number="$1"
	local issue_title="$2"
	local sanitized_title
	local branch_name

	sanitized_title=$(sanitize_branch_name "$issue_title")
	branch_name="GH-${issue_number}-${sanitized_title}"

	log_debug_stderr "Processing issue #$issue_number: '$issue_title'"
	log_debug_stderr "Branch name will be: '$branch_name'"

	# Check if branch already exists
	if git show-ref --verify --quiet "refs/heads/$branch_name"; then
		log_debug_stderr "Branch '$branch_name' already exists, skipping"
		return 1
	fi

	if [ "$DRY_RUN" = true ]; then
		echo "Would create branch: $branch_name (from $BASE_BRANCH)"
		return 0
	fi

	# Create the branch
	if git checkout -b "$branch_name" "$BASE_BRANCH" 2> /dev/null; then
		log_debug_stderr "Successfully created branch '$branch_name'"
		echo "Created branch: $branch_name"
		return 0
	else
		log_error_stderr "Failed to create branch '$branch_name'"
		return 1
	fi
}

create-branches() {
	log_info_stderr "Creating branches from open issues"
	log_debug_stderr "Repository: $REPO, Base branch: $BASE_BRANCH, Exclude labels: '$EXCLUDE_LABELS', Dry run: $DRY_RUN"

	# Check if base branch exists
	if ! check_base_branch; then
		local msg="Error: Base branch '$BASE_BRANCH' not found"
		local detail="The specified base branch does not exist locally or on remote. Please check the branch name or create it first."
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "BASE_BRANCH_NOT_FOUND" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "BASE_BRANCH_NOT_FOUND" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi

	# Fetch open issues using the fetch-issues script
	log_debug_stderr "Fetching open issues from $REPO"
	local fetch_args=(
		"-r" "$REPO"
		"--state" "open"
		"--json"
	)

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
		local msg="Error: Failed to fetch open issues"
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
	local all_issues_json
	if ! all_issues_json=$(echo "$issues_response" | jq -r '.detail' 2> /dev/null); then
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

	# Filter out issues with excluded labels
	log_debug_stderr "Filtering out issues with excluded labels: '$EXCLUDE_LABELS'"
	local issues_json
	local filter_expression
	filter_expression=$(build_exclude_filter "$EXCLUDE_LABELS")

	if ! issues_json=$(echo "$all_issues_json" | jq "$filter_expression" 2> /dev/null); then
		log_error_stderr "Failed to filter issues"
		local msg="Error: Failed to filter issues by labels"
		local detail="Could not filter out issues with excluded labels: '$EXCLUDE_LABELS'"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "FILTER_ERROR" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "FILTER_ERROR" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi

	# Count total issues after filtering
	local total_all_issues
	local total_issues
	if ! total_all_issues=$(echo "$all_issues_json" | jq length 2> /dev/null) || ! total_issues=$(echo "$issues_json" | jq length 2> /dev/null); then
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

	local filtered_count=$((total_all_issues - total_issues))
	log_info_stderr "Found $total_all_issues open issues, filtered out $filtered_count with excluded labels"
	log_info_stderr "Processing $total_issues eligible issues"

	if [ "$total_issues" -eq 0 ]; then
		local msg="No eligible issues found"
		local excluded_labels_msg=""
		if [ -n "$EXCLUDE_LABELS" ]; then
			excluded_labels_msg=" after filtering out issues with labels: '$EXCLUDE_LABELS'"
		fi
		local detail="No open issues found in repository $REPO$excluded_labels_msg"
		if [ "$JSON_OUTPUT" = true ]; then
			print_standard_json "OK" "$msg" "$detail"
		else
			print_standard_block "OK" "$msg" "$detail"
		fi
		return 0
	fi

	# Process each issue
	local created_branches=()
	local skipped_branches=()
	local failed_branches=()

	# Store current branch to return to it later
	local original_branch
	original_branch=$(git branch --show-current)

	while IFS=$'\t' read -r issue_number issue_title; do
		if create_branch_for_issue "$issue_number" "$issue_title"; then
			created_branches+=("GH-${issue_number}-$(sanitize_branch_name "$issue_title")")
		else
			if git show-ref --verify --quiet "refs/heads/GH-${issue_number}-$(sanitize_branch_name "$issue_title")"; then
				skipped_branches+=("GH-${issue_number}-$(sanitize_branch_name "$issue_title")")
			else
				failed_branches+=("GH-${issue_number}-$(sanitize_branch_name "$issue_title")")
			fi
		fi
	done < <(echo "$issues_json" | jq -r '.[] | [.number, .title] | @tsv')

	# Return to original branch if not in dry-run mode
	if [ "$DRY_RUN" = false ] && [ -n "$original_branch" ] && [ "$original_branch" != "$BASE_BRANCH" ]; then
		git checkout "$original_branch" 2> /dev/null || true
	fi

	# Prepare summary
	local created_count=${#created_branches[@]}
	local skipped_count=${#skipped_branches[@]}
	local failed_count=${#failed_branches[@]}

	# Prepare exclude labels array for JSON
	local exclude_labels_array="[]"
	if [ -n "$EXCLUDE_LABELS" ]; then
		local IFS=','
		read -ra labels_array <<< "$EXCLUDE_LABELS"
		local cleaned_labels=()
		for label in "${labels_array[@]}"; do
			# Trim whitespace
			label=$(echo "$label" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
			if [ -n "$label" ]; then
				cleaned_labels+=("$label")
			fi
		done
		if [ ${#cleaned_labels[@]} -gt 0 ]; then
			exclude_labels_array="$(printf '%s\n' "${cleaned_labels[@]}" | jq -R . | jq -s .)"
		fi
	fi

	local summary_json
	summary_json=$(jq -n \
		--argjson total_all "$total_all_issues" \
		--argjson total_eligible "$total_issues" \
		--argjson filtered_out "$filtered_count" \
		--argjson created "$created_count" \
		--argjson skipped "$skipped_count" \
		--argjson failed "$failed_count" \
		--argjson created_branches "$(printf '%s\n' "${created_branches[@]}" | jq -R . | jq -s .)" \
		--argjson skipped_branches "$(printf '%s\n' "${skipped_branches[@]}" | jq -R . | jq -s .)" \
		--argjson failed_branches "$(printf '%s\n' "${failed_branches[@]}" | jq -R . | jq -s .)" \
		--arg repo "$REPO" \
		--arg base_branch "$BASE_BRANCH" \
		--argjson exclude_labels "$exclude_labels_array" \
		--argjson dry_run "$DRY_RUN" \
		'{
			repository: $repo,
			base_branch: $base_branch,
			dry_run: $dry_run,
			filtering: {
				total_open_issues: $total_all,
				filtered_out_count: $filtered_out,
				eligible_issues: $total_eligible,
				excluded_labels: $exclude_labels
			},
			summary: {
				total_issues: $total_eligible,
				created_branches: $created,
				skipped_branches: $skipped,
				failed_branches: $failed
			},
			branches: {
				created: $created_branches,
				skipped: $skipped_branches,
				failed: $failed_branches
			}
		}')

	local success_status="OK"
	local message
	if [ "$DRY_RUN" = true ]; then
		message="Dry run completed: would create $created_count branches from $total_issues eligible issues (filtered from $total_all_issues total)"
	else
		message="Successfully processed $total_issues eligible issues: created $created_count branches, skipped $skipped_count existing, failed $failed_count"
	fi

	log_debug_stderr "Preparing output in requested format"
	if [ "$JSON_OUTPUT" = true ]; then
		log_debug_stderr "Outputting structured JSON format"
		print_standard_json "$success_status" "$message" "$summary_json"
	else
		log_debug_stderr "Outputting human-readable format"
		print_standard_block "$success_status" "$message" "$summary_json"
	fi

	log_info_stderr "Branch creation process completed"
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
	log_info_stderr "Parsed arguments - Repo: '$REPO', Base branch: '$BASE_BRANCH', Exclude labels: '$EXCLUDE_LABELS', Dry run: $DRY_RUN, JSON output: $JSON_OUTPUT, Debug level: ${DEBUG_LEVEL:-NONE}, Log file: ${LOG_FILE:-NONE}"

	validate_args
	log_debug_stderr "Argument validation completed successfully"

	check_dependencies
	log_debug_stderr "Dependency checks completed successfully"

	create-branches
	log_debug_stderr "Script execution completed successfully"
}

main "$@"
