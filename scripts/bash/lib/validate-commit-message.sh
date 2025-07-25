#!/bin/bash

# Validate commit message format
# Usage: validate-commit-message.sh <commit-msg-file>

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the commit message file
COMMIT_MSG_FILE="$1"

if [ ! -f "$COMMIT_MSG_FILE" ]; then
    echo -e "${RED}Error: Commit message file not found: $COMMIT_MSG_FILE${NC}"
    exit 1
fi

# Read the commit message (first line only)
COMMIT_MSG=$(head -n 1 "$COMMIT_MSG_FILE")

# Skip validation for merge commits
if [[ $COMMIT_MSG =~ ^Merge\ (branch|pull\ request) ]]; then
    echo -e "${GREEN}✓ Merge commit detected, skipping validation${NC}"
    exit 0
fi

# Define the pattern for GH-XXXX: [Message] format
# Format: GH-XXXX: [Message]
# Examples: GH-123: Add user authentication, GH-456: Fix login bug
PATTERN="^GH-[0-9]+: .+$"

# Check if commit message matches the pattern
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
    echo "  GH-XXXX = GitHub issue number (e.g., GH-123, GH-456)"
    echo "  Message = Brief description of the change"
    echo ""
    echo "Examples:"
    echo "  GH-123: Add user authentication feature"
    echo "  GH-456: Fix login timeout issue"
    echo "  GH-789: Update documentation for API endpoints"
    echo "  GH-321: Refactor database connection logic"
    echo ""
    echo "Note: The message should be descriptive and start with a capital letter."
    echo -e "${NC}"
    exit 1
fi
