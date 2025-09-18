#!/bin/bash

# -----------------------------------------------------------------------------
# @file validate-branch-name.sh
# @brief Validate Git branch name format against naming convention
#
# @description
#   Git hook script that validates the current branch name follows the required
#   format: GH-XXXX-descriptive-name. Skips validation for protected branches
#   (main, master, develop, staging, production). Provides detailed error
#   messages with examples when validation fails. Used as a pre-push Git hook
#   to enforce branch naming conventions.
#
# @usage
#   ./validate-branch-name.sh [--json] [--log FILE] [--debug [LEVEL]]
#   git push origin feature-branch  # Validates current branch name format
#
# @options
#   --json                Output result and errors in JSON format.
#   --log FILE            Write debug and operational logs to specified file
#   --debug [LEVEL]       Enable debug logging to stderr. Optional LEVEL:
#                         DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY
#                         (default: DEBUG if no level specified)
#   -h, --help            Show this help message and exit.
#
# @exitcodes
#   0  Success (branch name is valid or legitimately skipped)
#   1  Invalid usage, missing dependencies, or validation failure
# -----------------------------------------------------------------------------

set -euo pipefail

# Get the directory of the current script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/output-utils.sh"
source "${SCRIPT_DIR}/../lib/logging/watts/logging.sh"

# Default values for arguments
JSON_OUTPUT=false
DEBUG_LEVEL=""
LOG_FILE=""

show_usage() {
	echo "Usage:"
	echo "  $0 [--json] [--log FILE] [--debug [LEVEL]]"
	echo
	echo "Options:"
	echo "  --json                Output result and errors in JSON format."
	echo "  --log FILE            Write debug and operational logs to specified file"
	echo "  --debug [LEVEL]       Enable debug logging to stderr. Optional LEVEL:"
	echo "                        DEBUG, INFO, NOTICE, WARN, ERROR, CRITICAL, ALERT, EMERGENCY"
	echo "                        (default: DEBUG if no level specified)"
	echo "  -h, --help            Show this help message and exit."
	echo
	echo "Description:"
	echo "  Validates that the current Git branch name follows the convention:"
	echo "  GH-XXXX-descriptive-name"
}

parse_args() {
	JSON_OUTPUT=false
	DEBUG_LEVEL=""
	LOG_FILE=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
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
			-*)
				show_usage >&2
				exit 1
				;;
			*)
				# No positional arguments expected
				show_usage >&2
				exit 1
				;;
		esac
	done
}

check_dependencies() {
	log_debug_stderr "Checking script dependencies"

	# Check for git
	if ! command -v git > /dev/null 2>&1; then
		log_error_stderr "Missing dependency: git is not installed"
		local msg="Error: git is required but not installed."
		local detail="Install git to continue."
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "MISSING_DEPENDENCY" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "MISSING_DEPENDENCY" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
	log_debug_stderr "git dependency check passed"
}

validate_args() {
	log_debug_stderr "Validating arguments (no required arguments for this script)"
	# This script has no required arguments, just validate we're in a Git repository
	if ! git rev-parse --git-dir > /dev/null 2>&1; then
		log_error_stderr "Not in a Git repository"
		local msg="Error: not in a Git repository"
		local detail="This script must be run from within a Git repository"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "NOT_GIT_REPO" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "NOT_GIT_REPO" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
	log_debug_stderr "Git repository validation passed"
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

# Pure function to get current branch name
get_current_branch() {
	git branch --show-current 2>/dev/null || echo ""
}

# Pure function to check if branch is protected
is_protected_branch() {
	local branch_name="$1"
	local protected_branches=("main" "master" "develop" "staging" "production")
	
	for protected in "${protected_branches[@]}"; do
		if [[ "$branch_name" == "$protected" ]]; then
			return 0
		fi
	done
	return 1
}

# Pure function to validate branch name format
is_valid_branch_format() {
	local branch_name="$1"
	local pattern="^GH-[0-9]+-[a-z0-9-]+$"
	[[ $branch_name =~ $pattern ]]
}

# Function to generate branch name validation error details
generate_branch_name_error_detail() {
	local current_branch="$1"
	
	cat << EOF
Current branch: $current_branch

Expected format: GH-XXXX-descriptive-name

Where:
  GH-XXXX           = GitHub issue number (e.g., GH-80, GH-123)
  descriptive-name  = Descriptive name (lowercase, hyphens allowed)

Valid examples:
  GH-80-husky-hook-commit-message-should-match-branch-name
  GH-123-user-authentication
  GH-456-login-timeout-fix
  GH-789-security-patch
  GH-321-api-optimization
  GH-654-update-readme
  GH-987-refactor-auth-service
  GH-246-user-registration-tests
  GH-135-update-dependencies

Invalid examples:
  feature/user-auth        # Missing GH issue number
  GH-123                   # Missing descriptive name
  gh-123-user-auth         # Lowercase GH prefix
  GH-user-auth             # Missing issue number
  GH-123_user_auth         # Using underscores instead of hyphens
  GH-123-USER-AUTH         # All uppercase (should be lowercase except GH)

To rename your current branch:
  git branch -m GH-XXXX-descriptive-name
EOF
}

validate_branch_name() {
	log_info_stderr "Starting branch name validation"
	
	# Extract current branch name using pure function
	local branch_name
	branch_name=$(get_current_branch)
	log_debug_stderr "Current branch: '$branch_name'"
	
	# Check if branch name was successfully retrieved
	if [ -z "$branch_name" ]; then
		log_error_stderr "Could not determine current branch name"
		local msg="Error: could not determine current branch name"
		local detail="This may occur in detached HEAD state or if not in a Git repository"
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "NO_BRANCH" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "NO_BRANCH" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
	
	# Check if we should skip validation for protected branches
	if is_protected_branch "$branch_name"; then
		log_info_stderr "Protected branch detected, skipping validation"
		local msg="Protected branch detected, validation skipped"
		local detail="Branch: '$branch_name', Protected branches: main, master, develop, staging, production"
		if [ "$JSON_OUTPUT" = true ]; then
			print_standard_json "OK" "$msg" "$detail"
		else
			print_standard_block "OK" "$msg" "$detail"
		fi
		return 0
	fi
	
	# Validate branch name format
	if is_valid_branch_format "$branch_name"; then
		log_info_stderr "Branch name format is valid: '$branch_name'"
		local msg="Branch name format is valid"
		local detail="Branch: '$branch_name'"
		if [ "$JSON_OUTPUT" = true ]; then
			print_standard_json "OK" "$msg" "$detail"
		else
			print_standard_block "OK" "$msg" "$detail"
		fi
		return 0
	else
		log_error_stderr "Invalid branch name format: '$branch_name'"
		local msg="Invalid branch name format"
		local detail
		detail=$(generate_branch_name_error_detail "$branch_name")
		local func="${FUNCNAME[0]}"
		if [ "$JSON_OUTPUT" = true ]; then
			print_error_json "$msg" "$detail" "INVALID_BRANCH_FORMAT" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		else
			print_error_block "$msg" "$detail" "INVALID_BRANCH_FORMAT" "${LINENO}" "${BASH_SOURCE[0]}" "$func"
		fi
		exit 1
	fi
}

main() {
	# Parse arguments first to check for debug flag
	parse_args "$@"

	# Initialize logging based on debug flag and log file
	init_script_logging "$DEBUG_LEVEL" "$LOG_FILE"

	log_debug_stderr "Starting script with arguments: $*"
	log_info_stderr "Parsed arguments - JSON output: $JSON_OUTPUT, Debug level: ${DEBUG_LEVEL:-NONE}, Log file: ${LOG_FILE:-NONE}"

	validate_args
	log_debug_stderr "Argument validation completed successfully"

	check_dependencies
	log_debug_stderr "Dependency checks completed successfully"

	validate_branch_name
	log_debug_stderr "Script execution completed successfully"
}

main "$@"
