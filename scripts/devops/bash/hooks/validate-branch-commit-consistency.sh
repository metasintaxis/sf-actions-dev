#!/bin/bash

# Validate that branch name and commit message issue number match
# Usage: validate-branch-commit-consistency.sh <commit-msg-file>

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the commit message file
COMMIT_MSG_FILE="$1"

if [ ! -f "$COMMIT_MSG_FILE" ]; then
	echo -e "${RED}Error: Commit message file not found: $COMMIT_MSG_FILE${NC}"
	exit 1
fi

# Read the commit message (first line only)
COMMIT_MSG=$(head -n 1 "$COMMIT_MSG_FILE")

# Get current branch name
BRANCH_NAME=$(git branch --show-current)

# Skip validation for protected branches
PROTECTED_BRANCHES=("main" "master" "develop" "staging" "production")
for protected in "${PROTECTED_BRANCHES[@]}"; do
	if [[ "$BRANCH_NAME" == "$protected" ]]; then
		echo -e "${BLUE}ℹ Protected branch '$BRANCH_NAME' detected, skipping validation${NC}"
		exit 0
	fi
done

# Skip validation for merge commits
if [[ $COMMIT_MSG =~ ^Merge\ (branch|pull\ request) ]]; then
	echo -e "${BLUE}ℹ Merge commit detected, skipping validation${NC}"
	exit 0
fi

# Extract issue number from branch name (BRANCH_CONVENTION.md)
# Expected: GH-XXXX-descriptive-name
if [[ $BRANCH_NAME =~ ^GH-([0-9]+)-[a-z0-9-]+$ ]]; then
	BRANCH_ISSUE="${BASH_REMATCH[1]}"
else
	echo -e "${RED}✗ Invalid branch name format!${NC}"
	echo -e "${YELLOW}Branch name '$BRANCH_NAME' does not follow the expected format${NC}"
	echo -e "${YELLOW}Expected: GH-XXXX-descriptive-name${NC}"
	exit 1
fi

# Extract issue number from commit message (COMMIT_CONVENTION.md)
# Expected: GH-XXXX: Message
if [[ $COMMIT_MSG =~ ^GH-([0-9]+):\ .*$ ]]; then
	COMMIT_ISSUE="${BASH_REMATCH[1]}"
else
	echo -e "${RED}✗ Invalid commit message format!${NC}"
	echo -e "${YELLOW}Commit message '$COMMIT_MSG' does not follow the expected format${NC}"
	echo -e "${YELLOW}Expected: GH-XXXX: [Message]${NC}"
	exit 1
fi

# Check if issue numbers match
if [[ "$BRANCH_ISSUE" == "$COMMIT_ISSUE" ]]; then
	echo -e "${GREEN}✓ Branch and commit issue numbers match: GH-$BRANCH_ISSUE${NC}"
	exit 0
else
	echo -e "${RED}✗ Branch and commit issue numbers do not match!${NC}"
	echo -e "${YELLOW}"
	echo "Branch:  GH-$BRANCH_ISSUE (from: $BRANCH_NAME)"
	echo "Commit:  GH-$COMMIT_ISSUE (from: $COMMIT_MSG)"
	echo ""
	echo "The GitHub issue number in your branch name must match your commit message."
	echo ""
	echo "Options to fix this:"
	echo "1. Update your commit message to match the branch:"
	echo "   GH-$BRANCH_ISSUE: [Your message]"
	echo ""
	echo "2. Or rename your branch to match the commit:"
	echo "   git branch -m GH-$COMMIT_ISSUE-descriptive-name"
	echo ""
	echo "Example of matching branch and commit:"
	echo "   Branch:  GH-80-husky-hook-commit-message-should-match-branch-name"
	echo "   Commit:  GH-80: Add commit message validation"
	echo -e "${NC}"
	exit 1
fi
