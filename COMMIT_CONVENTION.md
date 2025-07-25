# Commit Message Convention

This project uses a simple GitHub issue-based commit message format.

## Format

```text
GH-XXXX: [Message]
```

## Structure

- **GH-XXXX**: GitHub issue number (required)
- **Message**: Brief description of the change (required)

## Rules

1. **Issue Number**: Must start with `GH-` followed by the issue number
2. **Colon and Space**: Must have `: ` (colon followed by space) after the issue number
3. **Message**: Should be descriptive and start with a capital letter
4. **Length**: Keep the message concise but descriptive

## Examples

### Good ✅

```text
GH-123: Add user authentication feature
GH-456: Fix login timeout issue
GH-789: Update documentation for API endpoints
GH-321: Refactor database connection logic
GH-555: Remove deprecated methods
GH-888: Implement password reset functionality
```

### Bad ❌

```text
GH123: missing colon and space
gh-456: lowercase prefix
GH-789 missing colon
GH-321: fix bug (too vague)
Add authentication (missing issue reference)
Fixed stuff (no issue number and vague)
```

## Template

A commit message template is available in `.gitmessage`:

```text
GH-XXXX: [Brief summary of changes in 50 characters or less]

# Why is this change necessary? (Optional)
# 

# How does it address the issue? (Optional)
# 

# What side effects does this change have? (Optional)
# 

# ------------------------ >50 characters -------------------------
# Remember:
# - Use imperative mood: "Add feature" not "Added feature"
# - Reference GitHub issue: GH-123
# - Keep first line under 50 characters
# - Leave blank line after summary
# - Wrap body at 72 characters
# - Focus on what and why, not how
#
# Examples:
# GH-123: Add user authentication middleware
# GH-456: Fix memory leak in data processing
# GH-789: Update README with installation steps
```

You can configure Git to use this template:

```bash
git config commit.template .gitmessage
```

## Best Practices

- **Use imperative mood**: "Add feature" not "Added feature"
- **Keep the summary under 50 characters**
- **Leave a blank line after the summary**
- **Wrap the body at 72 characters**
- **Focus on what and why, not how**
- **Reference the GitHub issue number**

## Enforcement

This project uses Husky git hooks to automatically validate commit messages. If your commit message doesn't follow the convention, the commit will be rejected with helpful feedback.

## Bypassing Validation (Not Recommended)

In rare cases where you need to bypass validation:

```bash
git commit --no-verify -m "your message"
```

**Note**: This should only be used in exceptional circumstances and is generally discouraged.
