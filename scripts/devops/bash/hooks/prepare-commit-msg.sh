#!/bin/bash

# Prepare commit message with GitHub issue number from branch name
# Usage: prepare-commit-msg.sh <commit-msg-file> <commit-source> <commit-sha>

# Colors for output
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the commit message file and source
COMMIT_MSG_FILE="$1"
COMMIT_SOURCE="$2"

# Skip if this is an amend, merge, or already has a source
if [[ "$COMMIT_SOURCE" == "commit" ]] || [[ "$COMMIT_SOURCE" == "merge" ]] || [[ "$COMMIT_SOURCE" == "squash" ]]; then
	exit 0
fi

# Get current branch name
BRANCH_NAME=$(git branch --show-current)

# Skip for protected branches
PROTECTED_BRANCHES=("main" "master" "develop" "staging" "production")
for protected in "${PROTECTED_BRANCHES[@]}"; do
	if [[ "$BRANCH_NAME" == "$protected" ]]; then
		exit 0
	fi
done

# Extract GitHub issue number from branch name (BRANCH_CONVENTION.md)
# Expected: GH-XXXX-descriptive-name
if [[ $BRANCH_NAME =~ ^GH-([0-9]+)-[a-z0-9-]+$ ]]; then
	ISSUE_NUMBER="${BASH_REMATCH[1]}"
	PREFIX="GH-$ISSUE_NUMBER"

	# Read the current commit message
	CURRENT_MSG=$(cat "$COMMIT_MSG_FILE")

	# Check if the commit message already starts with the prefix or template format
	if [[ ! $CURRENT_MSG =~ ^GH-[0-9]+: ]] && [[ ! $CURRENT_MSG =~ ^GH-XXXX: ]]; then
		# Prepend the prefix to the commit message
		echo "$PREFIX: $CURRENT_MSG" > "$COMMIT_MSG_FILE"
		echo -e "${BLUE}ℹ Auto-prepended $PREFIX to commit message${NC}"
	elif [[ $CURRENT_MSG =~ ^GH-XXXX: ]]; then
		# Replace the template with the actual prefix
		UPDATED_MSG=$(echo "$CURRENT_MSG" | sed "s|^GH-XXXX:|$PREFIX:|")
		echo "$UPDATED_MSG" > "$COMMIT_MSG_FILE"
		echo -e "${BLUE}ℹ Replaced template with $PREFIX in commit message${NC}"
	fi
else
	echo -e "${YELLOW}⚠ Could not extract GitHub issue number from branch '$BRANCH_NAME'${NC}"
	echo -e "${YELLOW}Expected format: GH-XXXX-descriptive-name${NC}"
fi
