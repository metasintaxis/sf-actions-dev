#!/bin/bash

# -----------------------------------------------------------------------------
# @file delete-old-branches.sh
# @brief Delete all local Git branches except 'dev' and 'main'
#
# @description
#   This script deletes all local Git branches except for the protected branches
#   'dev' and 'main'. It provides a safe way to clean up old feature branches,
#   issue branches, and other temporary branches while preserving the main
#   development branches. The script includes dry-run functionality to preview
#   which branches would be deleted before actually performing the operation.
#
# @usage
#   ./delete-old-branches.sh [--dry-run] [--json] [--log FILE] [--debug [LEVEL]]
#   ./delete-old-branches.sh --dry-run [--json] [--log FILE] [--debug [LEVEL]]
#
# @options
#   --dry-run             Show which branches would be deleted without actually deleting them.
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
DRY_RUN=false
JSON_OUTPUT=false
DEBUG_LEVEL=""
LOG_FILE=""

# Protected branches that should never be deleted
PROTECTED_BRANCHES=("dev" "main")

show_usage() {
	echo "Usage:"
	echo "  $0 [--dry-run] [--json] [--log FILE] [--debug [LEVEL]]"
	echo
	echo "Options:"
	echo "  --dry-run             Show which branches would be deleted without actually deleting them."
	echo "  --json                Output result and errors in JSON format."
	echo "  --log FILE            Write debug and operational logs to specified file"
	echo "  --debug [LEVEL]       Enable debug logging to stderr. Optional LEVEL:"
	echo "                        DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY"
	echo "                        (default: DEBUG if no level specified)"
	echo "  -h, --help            Show this help message and exit."
	echo
	echo "Description:"
	echo "  This script deletes all local Git branches except for the protected"
	echo "  branches 'dev' and 'main'. This is useful for cleaning up old feature"
	echo "  branches, issue branches, and other temporary branches."
	echo
	echo "Protected branches (never deleted):"
	echo "  - dev"
	echo "  - main"
	echo
	echo "Examples:"
	echo "  $0 --dry-run                    # Preview which branches would be deleted"
	echo "  $0                              # Delete all non-protected branches"
	echo "  $0 --json --debug INFO          # Delete with JSON output and debug logging"
}

parse_args() {
	DRY_RUN=false
	JSON_OUTPUT=false
	DEBUG_LEVEL=""
	LOG_FILE=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
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

	# Check for jq (for JSON output formatting)
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
	log_debug_stderr "Validating arguments (no required arguments for this script)"
	# No required arguments for this script
	log_debug_stderr "All arguments are valid"
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

# Function to check if a branch is protected
is_protected_branch() {
	local branch="$1"
	local protected_branch
	
	for protected_branch in "${PROTECTED_BRANCHES[@]}"; do
		if [ "$branch" = "$protected_branch" ]; then
			return 0  # Branch is protected
		fi
	done
	return 1  # Branch is not protected
}

# Function to get the current branch
get_current_branch() {
	git branch --show-current 2>/dev/null || echo ""
}

# Function to switch to a safe branch before deletion
switch_to_safe_branch() {
	local current_branch="$1"
	local safe_branch=""
	
	# Find a safe branch to switch to
	for protected_branch in "${PROTECTED_BRANCHES[@]}"; do
		if git show-ref --verify --quiet "refs/heads/$protected_branch"; then
			safe_branch="$protected_branch"
			break
		fi
	done
	
	if [ -z "$safe_branch" ]; then
		log_error_stderr "No protected branches found to switch to"
		return 1
	fi
	
	if [ "$current_branch" != "$safe_branch" ] && ! is_protected_branch "$current_branch"; then
		log_debug_stderr "Switching from '$current_branch' to '$safe_branch' before deletion"
		if ! git checkout "$safe_branch" 2>/dev/null; then
			log_error_stderr "Failed to switch to safe branch '$safe_branch'"
			return 1
		fi
	fi
	
	return 0
}

delete-old-branches() {
	log_info_stderr "Starting branch cleanup process"
	log_debug_stderr "Dry run: $DRY_RUN"

	# Get current branch
	local current_branch
	current_branch=$(get_current_branch)
	
	if [ -z "$current_branch" ]; then
		log_error_stderr "Could not determine current branch"
		local msg="Error: Unable to determine current Git branch"
		local detail="This may indicate a detached HEAD state or other Git issues"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "BRANCH_ERROR" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "BRANCH_ERROR" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
	
	log_debug_stderr "Current branch: '$current_branch'"

	# Get all local branches
	local all_branches=()
	local branches_to_delete=()
	local protected_branches_found=()
	
	# Read branches into array
	while IFS= read -r branch; do
		# Remove leading/trailing whitespace and asterisk from current branch
		branch=$(echo "$branch" | sed 's/^[* ]*//' | sed 's/ *$//')
		if [ -n "$branch" ]; then
			all_branches+=("$branch")
		fi
	done < <(git branch --format='%(refname:short)' 2>/dev/null)
	
	log_debug_stderr "Found ${#all_branches[@]} total local branches"
	
	# Categorize branches
	for branch in "${all_branches[@]}"; do
		if is_protected_branch "$branch"; then
			protected_branches_found+=("$branch")
			log_debug_stderr "Protected branch found: '$branch'"
		else
			branches_to_delete+=("$branch")
			log_debug_stderr "Branch to delete: '$branch'"
		fi
	done
	
	local total_branches=${#all_branches[@]}
	local protected_count=${#protected_branches_found[@]}
	local delete_count=${#branches_to_delete[@]}
	
	log_info_stderr "Found $total_branches total branches: $protected_count protected, $delete_count to delete"
	
	# Check if there are any branches to delete
	if [ "$delete_count" -eq 0 ]; then
		local msg="No branches to delete"
		local detail="All local branches are protected (dev, main) or no additional branches exist"
		local summary_json
		summary_json=$(jq -n \
			--argjson total_branches "$total_branches" \
			--argjson protected_count "$protected_count" \
			--argjson delete_count "$delete_count" \
			--argjson protected_branches "$(printf '%s\n' "${protected_branches_found[@]}" | jq -R . | jq -s .)" \
			--argjson dry_run "$DRY_RUN" \
			--arg current_branch "$current_branch" \
			'{
				current_branch: $current_branch,
				dry_run: $dry_run,
				summary: {
					total_branches: $total_branches,
					protected_branches: $protected_count,
					branches_to_delete: $delete_count,
					deleted_branches: 0,
					failed_deletions: 0
				},
				branches: {
					protected: $protected_branches,
					to_delete: [],
					deleted: [],
					failed: []
				}
			}')
		
		if [ "$JSON_OUTPUT" = true ]; then
			print_standard_json "OK" "$msg" "$summary_json"
		else
			print_standard_block "OK" "$msg" "$summary_json"
		fi
		return 0
	fi

	# If not in dry-run mode, switch to a safe branch if current branch will be deleted
	if [ "$DRY_RUN" = false ] && ! is_protected_branch "$current_branch"; then
		log_debug_stderr "Current branch '$current_branch' will be deleted, switching to safe branch"
		if ! switch_to_safe_branch "$current_branch"; then
			local msg="Error: Cannot switch to safe branch for deletion"
			local detail="Unable to find or switch to a protected branch (dev, main) before deleting current branch"
			local func="${FUNCNAME[0]}"
			if [ "$JSON_OUTPUT" = true ]; then
				print_error_json "$msg" "$detail" "BRANCH_SWITCH_ERROR" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
			else
				print_error_block "$msg" "$detail" "BRANCH_SWITCH_ERROR" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
			fi
			exit 1
		fi
	fi

	# Process branch deletions
	local deleted_branches=()
	local failed_branches=()
	
	for branch in "${branches_to_delete[@]}"; do
		log_debug_stderr "Processing branch for deletion: '$branch'"
		
		if [ "$DRY_RUN" = true ]; then
			echo "Would delete branch: $branch"
			deleted_branches+=("$branch")
		else
			if git branch -D "$branch" 2>/dev/null; then
				echo "Deleted branch: $branch"
				deleted_branches+=("$branch")
				log_debug_stderr "Successfully deleted branch: '$branch'"
			else
				echo "Failed to delete branch: $branch" >&2
				failed_branches+=("$branch")
				log_error_stderr "Failed to delete branch: '$branch'"
			fi
		fi
	done
	
	# Prepare final summary
	local deleted_count=${#deleted_branches[@]}
	local failed_count=${#failed_branches[@]}
	
	# Handle empty arrays safely for bash strict mode
	local protected_json="[]"
	local to_delete_json="[]"
	local deleted_json="[]"
	local failed_json="[]"
	
	if [ ${#protected_branches_found[@]} -gt 0 ]; then
		protected_json="$(printf '%s\n' "${protected_branches_found[@]}" | jq -R . | jq -s .)"
	fi
	
	if [ ${#branches_to_delete[@]} -gt 0 ]; then
		to_delete_json="$(printf '%s\n' "${branches_to_delete[@]}" | jq -R . | jq -s .)"
	fi
	
	if [ ${#deleted_branches[@]} -gt 0 ]; then
		deleted_json="$(printf '%s\n' "${deleted_branches[@]}" | jq -R . | jq -s .)"
	fi
	
	if [ ${#failed_branches[@]} -gt 0 ]; then
		failed_json="$(printf '%s\n' "${failed_branches[@]}" | jq -R . | jq -s .)"
	fi

	local summary_json
	summary_json=$(jq -n \
		--argjson total_branches "$total_branches" \
		--argjson protected_count "$protected_count" \
		--argjson delete_count "$delete_count" \
		--argjson deleted_count "$deleted_count" \
		--argjson failed_count "$failed_count" \
		--argjson protected_branches "$protected_json" \
		--argjson branches_to_delete "$to_delete_json" \
		--argjson deleted_branches "$deleted_json" \
		--argjson failed_branches "$failed_json" \
		--argjson dry_run "$DRY_RUN" \
		--arg current_branch "$current_branch" \
		'{
			current_branch: $current_branch,
			dry_run: $dry_run,
			summary: {
				total_branches: $total_branches,
				protected_branches: $protected_count,
				branches_to_delete: $delete_count,
				deleted_branches: $deleted_count,
				failed_deletions: $failed_count
			},
			branches: {
				protected: $protected_branches,
				to_delete: $branches_to_delete,
				deleted: $deleted_branches,
				failed: $failed_branches
			}
		}')

	local success_status="OK"
	local message
	if [ "$DRY_RUN" = true ]; then
		message="Dry run completed: would delete $delete_count branches (found $total_branches total, $protected_count protected)"
	else
		if [ "$failed_count" -eq 0 ]; then
			message="Successfully deleted $deleted_count branches (found $total_branches total, $protected_count protected)"
		else
			message="Deleted $deleted_count branches, failed to delete $failed_count branches (found $total_branches total, $protected_count protected)"
		fi
	fi

	log_debug_stderr "Preparing output in requested format"
	if [ "$JSON_OUTPUT" = true ]; then
		log_debug_stderr "Outputting structured JSON format"
		print_standard_json "$success_status" "$message" "$summary_json"
	else
		log_debug_stderr "Outputting human-readable format"
		print_standard_block "$success_status" "$message" "$summary_json"
	fi

	log_info_stderr "Branch cleanup process completed"
}

main() {
	# Parse arguments first to check for debug flag
	parse_args "$@"

	# Initialize logging based on debug flag and log file
	init_script_logging "$DEBUG_LEVEL" "$LOG_FILE"

	log_debug_stderr "Starting script with arguments: $*"
	log_info_stderr "Parsed arguments - Dry run: $DRY_RUN, JSON output: $JSON_OUTPUT, Debug level: ${DEBUG_LEVEL:-NONE}, Log file: ${LOG_FILE:-NONE}"

	validate_args
	log_debug_stderr "Argument validation completed successfully"

	check_dependencies
	log_debug_stderr "Dependency checks completed successfully"

	delete-old-branches
	log_debug_stderr "Script execution completed successfully"
}

main "$@"
