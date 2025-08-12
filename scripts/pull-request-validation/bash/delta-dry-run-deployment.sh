#!/bin/bash

# -----------------------------------------------------------------------------
# @file scripts/bash/ci/delta-dry-run-deployment.sh
# @brief CI Delta Deployment - Delta package deployment for Salesforce
#
# @description
#   This script performs delta deployment analysis and dry-run deployment
#   to Salesforce orgs. It calculates changes between branches, extracts
#   test classes, and runs deployment validation.
#
# @usage
#   ./delta-deployment.sh --base-branch BRANCH [OPTIONS]
#
# @options
#   --base-branch BRANCH  Base branch for delta calculation (required)
#   --target-org ORG      Target Salesforce org (optional, uses default if not specified)
#   --dry-run             Perform dry-run deployment (default: true)
#   --json                Output result and errors in JSON format
#   --log FILE            Write debug and operational logs to specified file
#   --debug [LEVEL]       Enable debug logging (DEBUG, INFO, WARN, ERROR, etc.)
#   -h, --help            Show this help message and exit
#
# @exitcodes
#   0  Success - deployment completed
#   1  Error during execution
#   2  No changes detected (deployment skipped)
# -----------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/output-utils.sh"
source "${SCRIPT_DIR}/../lib/logging/watts/logging.sh"

# Global variables
BASE_BRANCH=""
TARGET_ORG=""
DRY_RUN=true
JSON_OUTPUT=false
DEBUG_LEVEL=""
LOG_FILE=""
CONTEXT_FILE="${GITHUB_WORKSPACE:-$(pwd)}/delta-deployment-context.json"

show_usage() {
    echo "Usage:"
    echo "  $0 --base-branch BRANCH [OPTIONS]"
    echo
    echo "Options:"
    echo "  --base-branch BRANCH  Base branch for delta calculation (required)"
    echo "  --target-org ORG      Target Salesforce org (optional, uses default if not specified)"
    echo "  --dry-run             Perform dry-run deployment (default: true)"
    echo "  --json                Output result and errors in JSON format"
    echo "  --log FILE            Write debug and operational logs to specified file"
    echo "  --debug [LEVEL]       Enable debug logging (DEBUG, INFO, WARN, ERROR, etc.)"
    echo "  -h, --help            Show this help message and exit"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --base-branch)
                BASE_BRANCH="$2"
                shift 2
                ;;
            --target-org)
                TARGET_ORG="$2"
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
                if [[ $# -gt 1 && ! "$2" =~ ^- ]]; then
                    DEBUG_LEVEL="$2"
                    shift 2
                else
                    DEBUG_LEVEL="DEBUG"
                    shift
                fi
                ;;
            -h | --help)
                show_usage
                exit 0
                ;;
            *)
                log_error_stderr "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

validate_args() {
    if [ -z "$BASE_BRANCH" ]; then
        log_error_stderr "Missing required argument: --base-branch"
        show_usage
        exit 1
    fi
}

init_script_logging() {
    local logger_args=()
    local effective_level="INFO"

    if [ "${ACTIONS_STEP_DEBUG:-false}" = "true" ] || [ -n "$DEBUG_LEVEL" ]; then
        effective_level="${DEBUG_LEVEL:-DEBUG}"
    fi

    logger_args+=(--level "$effective_level")
    if [ -n "$LOG_FILE" ]; then
        logger_args+=(--log "$LOG_FILE")
    fi

    init_logger "${logger_args[@]}"
    log_info_stderr "Delta deployment started for base branch: $BASE_BRANCH"
}

# Save context for communication with other scripts
save_context() {
    local key="$1"
    local value="$2"
    
    # Create context file if it doesn't exist
    if [ ! -f "$CONTEXT_FILE" ]; then
        echo "{}" > "$CONTEXT_FILE"
    fi
    
    # Update context
    jq --arg key "$key" --arg value "$value" '.[$key] = $value' "$CONTEXT_FILE" > "${CONTEXT_FILE}.tmp" && mv "${CONTEXT_FILE}.tmp" "$CONTEXT_FILE"
    log_debug_stderr "Saved context: $key = $value"
}

determine_from_branch() {
    local from_branch="$BASE_BRANCH"
    
    # Validate supported branches
    case "$from_branch" in
        dev|devops/actions-test)
            from_branch="origin/$from_branch"
            ;;
        GH-[0-9]*)
            from_branch="origin/$from_branch"
            ;;
        *)
            log_error_stderr "Unsupported base branch: $from_branch"
            if [ "$JSON_OUTPUT" = true ]; then
                print_error_json "Unsupported base branch: $from_branch" "" "UNSUPPORTED_BRANCH" "${LINENO[0]}" "${BASH_SOURCE[0]}" "${FUNCNAME[0]}"
            fi
            exit 1
            ;;
    esac
    
    save_context "from_branch" "$from_branch"
    log_info_stderr "Using FROM_BRANCH: $from_branch"
    echo "$from_branch"
}

calculate_delta_changes() {
    local from_branch="$1"
    
    log_info_stderr "Calculating delta changes from $from_branch to HEAD"
    
    # Create delta-sources directory if it doesn't exist
    mkdir -p delta-sources
    
    if ! sf sgd source delta --to "HEAD" --from "$from_branch" --output-dir "delta-sources" --generate-delta -i .forceignore; then
        log_error_stderr "Failed to calculate delta changes"
        if [ "$JSON_OUTPUT" = true ]; then
            print_error_json "Failed to calculate delta changes" "" "DELTA_CALCULATION_FAILED" "${LINENO[0]}" "${BASH_SOURCE[0]}" "${FUNCNAME[0]}"
        fi
        exit 1
    fi
    
    # Check if there are changes by examining the delta-sources directory
    if [ ! -d "delta-sources" ] || [ -z "$(find delta-sources -name "*.cls" -o -name "*.trigger" -o -name "*.component" -o -name "*.page" -o -name "*.xml" 2>/dev/null)" ]; then
        log_info_stderr "No changes detected in delta-sources directory"
        save_context "has_changes" "false"
        save_context "deployment_status" "skipped"
        
        if [ "$JSON_OUTPUT" = true ]; then
            print_standard_json "OK" "No deployment needed - no changes detected" "{\"changes\": false}"
        else
            print_standard_block "OK" "No deployment needed - no changes detected" ""
        fi
        exit 2  # Special exit code for no changes
    fi
    
    save_context "has_changes" "true"
    log_info_stderr "Changes detected, proceeding with deployment analysis"
    
    # Log the delta-sources content for debugging
    log_debug_stderr "Generated delta-sources directory content:"
    if [ "${DEBUG_LEVEL:-}" = "DEBUG" ]; then
        find delta-sources -type f -name "*.cls" -o -name "*.trigger" -o -name "*.component" -o -name "*.page" -o -name "*.xml" | head -20 >&2
    fi
}

extract_apex_test_classes() {
    local apex_classes=""
    
    log_info_stderr "Extracting Apex test classes from delta-sources directory"
    
    # Find all Apex class files in delta-sources and extract class names
    local class_files
    class_files=$(find delta-sources -name "*.cls" -type f 2>/dev/null || echo "")
    
    if [ -z "$class_files" ]; then
        log_info_stderr "No Apex classes found in delta-sources"
        save_context "apex_classes" ""
        return 0
    fi
    
    # Extract class names from file paths and build test command
    apex_classes=$(echo "$class_files" | while read -r class_file; do
        if [ -f "$class_file" ]; then
            basename "$class_file" .cls
        fi
    done | grep -v "^$" | sort -u | sed 's/^/--tests /' | tr '\n' ' ' | sed 's/ $//')
    
    save_context "apex_classes" "$apex_classes"
    
    if [ -n "$apex_classes" ]; then
        log_info_stderr "Apex classes for testing: $apex_classes"
    else
        log_info_stderr "No specific Apex test classes found, will use default test level"
    fi
}

run_dry_run_deployment() {
    local apex_classes="$1"
    
    log_info_stderr "Starting delta deployment (dry-run: $DRY_RUN)"
    
    # Build deployment command using source-dir instead of manifest
    local deploy_cmd="sf project deploy start --source-dir delta-sources --async --ignore-warnings"
    
    if [ "$DRY_RUN" = true ]; then
        deploy_cmd="$deploy_cmd --dry-run"
    fi
    
    # Note: destructive changes handling may need to be adjusted based on how sfdx-git-delta generates them
    if [ -f delta-sources/destructiveChanges.xml ]; then
        deploy_cmd="$deploy_cmd --post-destructive-changes delta-sources/destructiveChanges.xml"
        log_debug_stderr "Including destructive changes"
    fi
    
    if [ -n "$apex_classes" ]; then
        deploy_cmd="$deploy_cmd --test-level RunSpecifiedTests $apex_classes"
        log_debug_stderr "Using specified test classes"
    else
        log_debug_stderr "Using default test level"
    fi
    
    if [ -n "$TARGET_ORG" ]; then
        deploy_cmd="$deploy_cmd --target-org $TARGET_ORG"
    fi
    
    deploy_cmd="$deploy_cmd --json"
    
    log_debug_stderr "Deployment command: $deploy_cmd"
    
    # Execute deployment
    local deploy_result
    local deploy_status=0
    deploy_result=$(eval "$deploy_cmd") || deploy_status=$?
    
    if [ $deploy_status -ne 0 ]; then
        log_error_stderr "Deployment failed to start"
        save_context "deployment_status" "failed"
        if [ "$JSON_OUTPUT" = true ]; then
            print_error_json "Deployment failed to start" "$deploy_result" "DEPLOYMENT_START_FAILED" "${LINENO[0]}" "${BASH_SOURCE[0]}" "${FUNCNAME[0]}"
        fi
        exit 1
    fi
    
    # Extract deployment ID
    local deploy_id
    deploy_id=$(echo "$deploy_result" | jq -r '.result.id')
    save_context "deployment_id" "$deploy_id"
    log_info_stderr "Deployment started with ID: $deploy_id"
    
    echo "$deploy_id"
}

wait_for_deployment() {
    local deploy_id="$1"
    
    log_info_stderr "Waiting for deployment to complete (max 180 minutes)"
    
    if ! sf project deploy resume --job-id "$deploy_id" --wait 180; then
        log_error_stderr "Deployment failed or timed out"
        save_context "deployment_status" "failed"
        if [ "$JSON_OUTPUT" = true ]; then
            print_error_json "Deployment failed or timed out" "" "DEPLOYMENT_FAILED" "${LINENO[0]}" "${BASH_SOURCE[0]}" "${FUNCNAME[0]}"
        fi
        exit 1
    fi
    
    # Get final status
    local final_status
    final_status=$(sf project deploy report --job-id "$deploy_id" --json | jq -r '.result.status')
    save_context "deployment_status" "$final_status"
    
    if [ "$final_status" != "Succeeded" ]; then
        log_error_stderr "Deployment failed with status: $final_status"
        if [ "$JSON_OUTPUT" = true ]; then
            print_error_json "Deployment failed with status: $final_status" "" "DEPLOYMENT_FAILED" "${LINENO[0]}" "${BASH_SOURCE[0]}" "${FUNCNAME[0]}"
        fi
        exit 1
    fi
    
    log_info_stderr "Deployment completed successfully with status: $final_status"
    echo "$final_status"
}

generate_summary() {
    local deploy_id="$1"
    local final_status="$2"
    
    save_context "deployment_timestamp" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    
    if [ "$JSON_OUTPUT" = true ]; then
        print_standard_json "OK" "Deployment succeeded" "{\"deployment_id\": \"$deploy_id\", \"status\": \"$final_status\", \"dry_run\": $DRY_RUN}"
    else
        local deployment_type="deployment"
        if [ "$DRY_RUN" = true ]; then
            deployment_type="dry-run deployment"
        fi
        print_standard_block "OK" "Delta $deployment_type succeeded" "Deployment ID: $deploy_id"
    fi
}

main() {
    parse_args "$@"
    validate_args
    init_script_logging
    
    # Determine source branch
    local from_branch
    from_branch=$(determine_from_branch)
    
    # Calculate delta changes
    calculate_delta_changes "$from_branch"
    
    # Extract Apex test classes
    extract_apex_test_classes
    local apex_classes
    apex_classes=$(jq -r '.apex_classes // ""' "$CONTEXT_FILE" 2>/dev/null || echo "")
    
    # Run deployment
    local deploy_id
    deploy_id=$(run_dry_run_deployment "$apex_classes")
    
    # Wait for completion
    local final_status
    final_status=$(wait_for_deployment "$deploy_id")
    
    # Generate summary
    generate_summary "$deploy_id" "$final_status"
    
    log_info_stderr "Delta deployment completed successfully"
}

main "$@"