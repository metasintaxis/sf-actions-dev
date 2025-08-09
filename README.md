# metasintaxis/sf-actions-dev

This repository is for the development and testing of GitHub workflows that
automate deployments, analyses, and report generation for Salesforce instances.

## Development Conventions

This project enforces strict naming and messaging conventions to maintain consistency and traceability across all development work.

### Branch Naming Convention

All feature branches must follow this format:

```text
GH-XXXX-descriptive-name
```

- **GH-XXXX**: GitHub issue number (e.g., GH-80, GH-123)
- **descriptive-name**: Short, lowercase, hyphen-separated summary

**Examples:**

- `GH-80-husky-hook-commit-message-should-match-branch-name`
- `GH-123-user-authentication`
- `GH-456-login-timeout-fix`

See [BRANCH_CONVENTION.md](./BRANCH_CONVENTION.md) for complete details.

### Commit Message Convention

All commit messages must follow this format:

```text
GH-XXXX: [Message]
```

- **GH-XXXX**: GitHub issue number (must match branch)
- **Message**: Brief description starting with a capital letter

**Examples:**

- `GH-80: Add commit message validation`
- `GH-123: Add user authentication feature`
- `GH-456: Fix login timeout issue`

See [COMMIT_CONVENTION.md](./COMMIT_CONVENTION.md) for complete details.

### Enforcement

Both conventions are automatically enforced via Husky Git hooks:

- **Pre-commit**: Validates branch name format
- **Prepare-commit-msg**: Auto-prepends GitHub issue number
- **Commit-msg**: Validates commit message format and consistency

### Quick Start

1. Create a GitHub issue for your work
2. Create a properly named branch:

   ```bash
   git checkout -b GH-123-your-feature-description
   ```

3. Make your changes and commit:

   ```bash
   git commit -m "Add your feature implementation"
   # Auto-prepends to: "GH-123: Add your feature implementation"
   ```

4. Push and create a pull request

### Bypassing Validation

Only use in exceptional circumstances:

```bash
git commit --no-verify -m "your message"
```

For more details on conventions and validation, see the individual
