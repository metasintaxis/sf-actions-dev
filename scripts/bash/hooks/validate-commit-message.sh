#!/bin/bash

# Validate commit message format
# Usage: validate-commit-message.sh <commit-msg-file>

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

COMMIT_MSG_FILE="$1"

if [ ! -f "$COMMIT_MSG_FILE" ]; then
	echo -e "${RED}Error: Commit message file not found: $COMMIT_MSG_FILE${NC}"
	exit 1
fi

COMMIT_MSG=$(head -n 1 "$COMMIT_MSG_FILE")

# Skip validation for merge commits
if [[ $COMMIT_MSG =~ ^Merge\ (branch|pull\ request) ]]; then
	echo -e "${GREEN}✓ Merge commit detected, skipping validation${NC}"
	exit 0
fi

# Pattern: GH-XXXX: Message (where XXXX is any number)
PATTERN="^GH-[0-9]+: [A-Z].{1,}$"

if [[ $COMMIT_MSG =~ $PATTERN ]]; then
	echo -e "${GREEN}✓ Commit message format is valid${NC}"
	exit 0
else
	echo -e "${RED}✗ Invalid commit message format!${NC}"
	echo -e "${YELLOW}"
	echo "Current message: $COMMIT_MSG"
	echo ""
	echo "Expected format: GH-XXXX: [Message]"
	echo ""
	echo "Where:"
	echo "  GH-XXXX   = GitHub issue number (e.g., GH-80, GH-123; XXXX is any number)"
	echo "  Message   = Brief description, starts with a capital letter"
	echo ""
	echo "Good examples:"
	echo "  GH-80: Add commit message validation"
	echo "  GH-123: Add user authentication feature"
	echo "  GH-456: Fix login timeout issue"
	echo "  GH-789: Update documentation for API endpoints"
	echo "  GH-321: Refactor database connection logic"
	echo "  GH-555: Remove deprecated methods"
	echo "  GH-888: Implement password reset functionality"
	echo ""
	echo "Bad examples:"
	echo "  GH80: missing colon and space"
	echo "  gh-456: lowercase prefix"
	echo "  GH-789 missing colon"
	echo "  GH-321: fix bug (too vague)"
	echo "  Add authentication (missing issue reference)"
	echo "  Fixed stuff (no issue number and vague)"
	echo ""
	echo "To use the commit message template:"
	echo "  git config commit.template .gitmessage"
	echo -e "${NC}"
	exit 1
fi
