# Branch Naming Convention

This project enforces a specific branch naming convention to maintain consistency and traceability.

## Format

```text
GH-XXXX-BRANCH-NAME
```

## Components

- **GH-XXXX**: GitHub issue number (e.g., GH-123, GH-456)
- **BRANCH**: Branch type (feature, bugfix, hotfix, etc.)
- **NAME**: Descriptive name (can include hyphens for multiple words)

## Branch Types

| Type | Description | Example |
|------|-------------|---------|
| `feature` | New features or functionality | `GH-123-feature-user-authentication` |
| `bugfix` | Bug fixes | `GH-456-bugfix-login-timeout` |
| `hotfix` | Critical/urgent fixes | `GH-789-hotfix-security-patch` |
| `enhancement` | Improvements to existing features | `GH-321-enhancement-api-optimization` |
| `docs` | Documentation updates | `GH-654-docs-update-readme` |
| `refactor` | Code refactoring without functionality changes | `GH-987-refactor-auth-service` |
| `test` | Adding or updating tests | `GH-246-test-user-registration` |
| `chore` | Maintenance tasks, dependencies, etc. | `GH-135-chore-update-dependencies` |

## Valid Examples

- `GH-123-feature-user-authentication`
- `GH-456-bugfix-login-timeout-issue`
- `GH-789-hotfix-security-vulnerability`
- `GH-321-enhancement-performance-optimization`
- `GH-654-docs-api-documentation`
- `GH-987-refactor-database-connection`
- `GH-246-test-integration-tests`
- `GH-135-chore-dependency-updates`

## Invalid Examples

❌ `feature/user-auth` - Missing GH issue number  
❌ `GH-123-feature` - Missing descriptive name  
❌ `gh-123-feature-auth` - Lowercase GH prefix  
❌ `GH-feature-auth` - Missing issue number  
❌ `GH-123_feature_auth` - Using underscores instead of hyphens  
❌ `GH-123-FEATURE-AUTH` - All uppercase (should be lowercase except GH)

## Protected Branches

The following branches are exempt from this naming convention:

- `main`
- `master`
- `develop`
- `staging`
- `production`

## Renaming a Branch

If your current branch doesn't follow the convention, rename it:

```bash
git branch -m GH-XXXX-BRANCH-NAME
```

Example:

```bash
git branch -m GH-123-feature-user-authentication
```

## Enforcement

Branch name validation runs automatically on every commit via Git hooks. If your branch name doesn't follow the convention, the commit will be rejected with helpful guidance.

To bypass validation (for exceptional cases):

```bash
git commit --no-verify
```

## Workflow Example

1. Create a GitHub issue (#123) for user authentication feature
2. Create and checkout a new branch:

   ```bash
   git checkout -b GH-123-feature-user-authentication
   ```

3. Make your changes and commit:

   ```bash
   git commit -m "GH-123: Add user authentication feature"
   ```

4. Push the branch:

   ```bash
   git push origin GH-123-feature-user-authentication
   ```

5. Create a pull request with a descriptive title referencing the issue

This convention ensures that:

- Every branch is linked to a specific GitHub issue
- Branch purpose is clear from the name
- Consistent naming across the entire project
- Easy filtering and organization of branches