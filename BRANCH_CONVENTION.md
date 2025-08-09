# Branch Naming Convention

This project enforces a simple branch naming convention for clarity and traceability.

## Format

```bash
GH-XXXX-descriptive-name
```

- **GH-XXXX**: GitHub issue number (e.g., GH-80, GH-123; `XXXX` is any number)
- **descriptive-name**: Short, lowercase, hyphen-separated summary

## Examples

**Valid:**

- `GH-80-husky-hook-commit-message-should-match-branch-name`
- `GH-123-user-authentication`
- `GH-456-login-timeout-fix`
- `GH-789-security-patch`
- `GH-321-api-optimization`
- `GH-654-update-readme`
- `GH-987-refactor-auth-service`
- `GH-246-user-registration-tests`
- `GH-135-update-dependencies`

**Invalid:**

- `feature/user-auth` (missing GH issue number)
- `GH-123` (missing descriptive name)
- `gh-123-user-auth` (lowercase GH prefix)
- `GH-user-auth` (missing issue number)
- `GH-123_user_auth` (underscores instead of hyphens)
- `GH-123-USER-AUTH` (all uppercase except GH)

## Protected Branches

These branches are exempt:
- `main`
- `master`
- `develop`
- `staging`
- `production`

## Renaming

To rename your branch:

```bash
git branch -m GH-XXXX-descriptive-name
```

## Workflow Example

1. Create a GitHub issue (e.g., #80)
2. Create a branch:  
   `git checkout -b GH-80-husky-hook-commit-message-should-match-branch-name`
3. Commit:  
   `git commit -m "GH-80: Add commit message validation"`
4. Push:  
   `git push origin GH-80-husky-hook-commit-message-should-match-branch-name`

## Enforcement

Branch name validation runs automatically via Git hooks. Use `git commit --no-verify` to bypass validation in exceptional cases.