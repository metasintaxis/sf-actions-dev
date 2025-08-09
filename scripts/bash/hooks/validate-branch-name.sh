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

# Define the pattern for GH-XXXX-descriptive-name format
# Format: GH-[number]-[descriptive-name]
PATTERN="^GH-[0-9]+-[a-z0-9-]+$"

# Check if branch name matches the pattern
if [[ $BRANCH_NAME =~ $PATTERN ]]; then
	echo -e "${GREEN}✓ Branch name format is valid: $BRANCH_NAME${NC}"
	exit 0
else
	echo -e "${RED}✗ Invalid branch name format!${NC}"
	echo -e "${YELLOW}"
	echo "Current branch: $BRANCH_NAME"
	echo ""
	echo "Expected format: GH-XXXX-descriptive-name"
	echo ""
	echo "Where:"
	echo "  GH-XXXX           = GitHub issue number (e.g., GH-80, GH-123)"
	echo "  descriptive-name  = Descriptive name (lowercase, hyphens allowed)"
	echo ""
	echo "Valid examples:"
	echo "  GH-80-husky-hook-commit-message-should-match-branch-name"
	echo "  GH-123-user-authentication"
	echo "  GH-456-login-timeout-fix"
	echo "  GH-789-security-patch"
	echo "  GH-321-api-optimization"
	echo "  GH-654-update-readme"
	echo "  GH-987-refactor-auth-service"
	echo "  GH-246-user-registration-tests"
	echo "  GH-135-update-dependencies"
	echo ""
	echo "Invalid examples:"
	echo "  feature/user-auth        # Missing GH issue number"
	echo "  GH-123                   # Missing descriptive name"
	echo "  gh-123-user-auth         # Lowercase GH prefix"
	echo "  GH-user-auth             # Missing issue number"
	echo "  GH-123_user_auth         # Using underscores instead of hyphens"
	echo "  GH-123-USER-AUTH         # All uppercase (should be lowercase except GH)"
	echo ""
	echo "To rename your current branch:"
	echo "  git branch -m GH-XXXX-descriptive-name"
	echo -e "${NC}"
	exit 1
fi
