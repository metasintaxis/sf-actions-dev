#!/bin/bash

# Validate branch name format
# Usage: validate-branch-name.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get current branch name
BRANCH_NAME=$(git branch --show-current)

# Skip validation for main/master branches and develop
PROTECTED_BRANCHES=("main" "master" "develop" "staging" "production")
for protected in "${PROTECTED_BRANCHES[@]}"; do
    if [[ "$BRANCH_NAME" == "$protected" ]]; then
        echo -e "${BLUE}ℹ Protected branch '$BRANCH_NAME' detected, skipping validation${NC}"
        exit 0
    fi
done

# Define the pattern for GH-XXXX-BRANCH-NAME format
# Format: GH-[number]-[word(s)]-[word(s)]
# Examples: GH-123-feature-authentication, GH-456-bugfix-login-timeout
PATTERN="^GH-[0-9]+-[a-zA-Z0-9]+-[a-zA-Z0-9-]+$"

# Check if branch name matches the pattern
if [[ $BRANCH_NAME =~ $PATTERN ]]; then
    echo -e "${GREEN}✓ Branch name format is valid: $BRANCH_NAME${NC}"
    exit 0
else
    echo -e "${RED}✗ Invalid branch name format!${NC}"
    echo -e "${YELLOW}"
    echo "Current branch: $BRANCH_NAME"
    echo ""
    echo "Expected format: GH-XXXX-BRANCH-NAME"
    echo ""
    echo "Where:"
    echo "  GH-XXXX = GitHub issue number (e.g., GH-123, GH-456)"
    echo "  BRANCH  = Branch type (feature, bugfix, hotfix, etc.)"
    echo "  NAME    = Descriptive name (can include hyphens)"
    echo ""
    echo "Valid examples:"
    echo "  GH-123-feature-user-authentication"
    echo "  GH-456-bugfix-login-timeout"
    echo "  GH-789-hotfix-security-patch"
    echo "  GH-321-enhancement-api-optimization"
    echo "  GH-654-docs-update-readme"
    echo ""
    echo "Common branch types:"
    echo "  feature   - New features"
    echo "  bugfix    - Bug fixes"
    echo "  hotfix    - Critical fixes"
    echo "  enhancement - Improvements"
    echo "  docs      - Documentation"
    echo "  refactor  - Code refactoring"
    echo "  test      - Testing"
    echo "  chore     - Maintenance tasks"
    echo ""
    echo "To rename your current branch:"
    echo "  git branch -m GH-XXXX-BRANCH-NAME"
    echo -e "${NC}"
    exit 1
fi