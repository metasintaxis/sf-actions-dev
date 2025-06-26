#!/bin/bash
# -----------------------------------------------------------------------------
# @file scripts/bash/environments/determine-target-environment.sh
# @brief Determines the target environment based on Git branch reference.
#
# @description
#   This script maps Git branch references to their corresponding deployment
#   environments. It outputs the environment name that can be used in GitHub
#   Actions workflows or other automation scripts.
#
# @usage
#   ./determine-target-environment.sh [BRANCH_REF]
#   
#   If no BRANCH_REF is provided, it will use the GITHUB_REF environment variable.
#
# @parameters
#   BRANCH_REF: Git branch reference (e.g., refs/heads/dev, refs/heads/main)
#
# @outputs
#   Environment name (DEV, QA, UAT, PREPROD, PROD)
#
# @examples
#   ./determine-target-environment.sh "refs/heads/dev"     # Outputs: DEV
#   ./determine-target-environment.sh "refs/heads/main"    # Outputs: PROD
#   GITHUB_REF="refs/heads/qa" ./determine-target-environment.sh  # Outputs: QA
# -----------------------------------------------------------------------------

set -euo pipefail

# Get the branch reference from parameter or environment variable
BRANCH_REF="${1:-${GITHUB_REF:-}}"

# Validate that we have a branch reference
if [[ -z "$BRANCH_REF" ]]; then
    echo "Error: No branch reference provided. Use parameter or set GITHUB_REF environment variable." >&2
    exit 1
fi

# Determine environment based on branch reference
case "$BRANCH_REF" in
    "refs/heads/dev" | "refs/heads/devops/actions" | "refs/heads/devops/actions-test")
        echo "DEV"
        ;;
    "refs/heads/qa")
        echo "QA"
        ;;
    "refs/heads/uat")
        echo "UAT"
        ;;
    "refs/heads/preprod")
        echo "PREPROD"
        ;;
    "refs/heads/prod" | "refs/heads/main")
        echo "PROD"
        ;;
    *)
        # Default to DEV for any other branch
        echo "DEV"
        ;;
esac
