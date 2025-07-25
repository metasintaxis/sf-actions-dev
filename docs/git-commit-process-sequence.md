# Git Commit Process Sequence

## Overview

This document outlines the actual sequence of processes that execute when performing a Git commit in this Salesforce Actions Development repository. The process includes automated validation, testing, formatting, and commit message validation.

## Commit Process Flow

```bash
git commit -m "GH-XXXX: message"
    ↓
1. Pre-commit Hook (.husky/pre-commit)
    ↓
2. npm test (runs sfdx-lwc-jest)
    ↓
3. lint-staged (automatic formatting & linting)
    ↓
4. Commit Message Hook (.husky/commit-msg)
    ↓
5. Actual Commit (if all steps pass)
```

## Detailed Process Sequence

### 1. Pre-commit Hook Execution

**File**: [.husky/pre-commit](.husky/pre-commit)

```bash
npm test
```

This triggers the test suite defined in [package.json](package.json):

- Executes `npm run test:unit`
- Runs `sfdx-lwc-jest` (Salesforce Lightning Web Component Jest tests)
- **Abort Condition**: If any test fails, the commit is aborted

### 2. Lint-staged Processing

**Configuration**: [package.json](package.json) `lint-staged` section

Automatically processes staged files based on file patterns:

#### For Files: `**/*.{cls,cmp,component,css,html,js,json,md,page,trigger,xml,yaml,yml}`
```bash
prettier --write
```
- Automatically formats staged files
- Modifies files in place if formatting changes are needed

#### For Files: `**/{aura,lwc}/**/*.js`
```bash
eslint
```
- Runs ESLint validation on Aura and LWC JavaScript files
- **Abort Condition**: If linting errors are found, the commit is aborted

### 3. Commit Message Validation

**File**: [.husky/commit-msg](.husky/commit-msg)

```bash
#!/bin/bash
./scripts/bash/lib/validate-commit-message.sh "$1"
```

**Validation Rules**:
- Must follow format: `GH-XXXX: [Brief description]`
- Based on [COMMIT_CONVENTION.md](COMMIT_CONVENTION.md)
- Uses commit message template from [.gitmessage](.gitmessage)
- **Abort Condition**: If message format is invalid, the commit is aborted

### 4. Final Commit

If all previous steps pass successfully, the actual Git commit is created.

## Supported File Types

The automation process handles these file extensions:
- **Salesforce**: `.cls`, `.cmp`, `.component`, `.page`, `.trigger`
- **Web**: `.css`, `.html`, `.js`
- **Configuration**: `.json`, `.xml`, `.yaml`, `.yml`
- **Documentation**: `.md`

## Commit Message Template

The repository provides a commit message template in [.gitmessage](.gitmessage):

```
GH-XXXX: [Brief summary of changes in 50 characters or less]

# Why is this change necessary? (Optional)
# 

# How does it address the issue? (Optional)
# 

# What side effects does this change have? (Optional)
# 
```

## Configuration Files

### Package.json Scripts
- `test`: Runs unit tests via `sfdx-lwc-jest`
- `lint`: ESLint validation for Aura/LWC components
- `prettier`: Code formatting
- `precommit`: Triggers lint-staged (automatic on commit)

### Husky Git Hooks
- **Pre-commit**: Runs tests and formatting
- **Commit-msg**: Validates commit message format

## Debugging Failed Commits

### Test Failures
```bash
# Run tests manually
npm run test

# Run tests with coverage
npm run test:unit:coverage

# Run tests in watch mode during development
npm run test:unit:watch
```

### Formatting Issues
```bash
# Check formatting without changing files
npm run prettier:verify

# Auto-fix formatting issues
npm run prettier
```

### Linting Issues
```bash
# Run linting manually
npm run lint
```

### Commit Message Issues
```bash
# Check commit message format manually
./scripts/bash/lib/validate-commit-message.sh "GH-123: Your message"
```

## Best Practices

### 1. Pre-commit Preparation
- Run tests locally before committing: `npm test`
- Format code: `npm run prettier`
- Lint code: `npm run lint`

### 2. Commit Message Format
- Always start with `GH-XXXX:` where XXXX is the GitHub issue number
- Keep the summary under 50 characters
- Use imperative mood: "Add feature" not "Added feature"

### 3. Branch Naming
- Follow convention: `GH-XXXX-branch-description`
- Reference [BRANCH_CONVENTION.md](BRANCH_CONVENTION.md)

### 4. Incremental Commits
- Make small, focused commits
- Each commit should represent a logical change
- Test after each commit to ensure stability

## Troubleshooting

### Common Issues

1. **Tests Failing**: Check [force-app/](force-app/) for LWC test files
2. **Prettier Conflicts**: Run `npm run prettier` to auto-fix
3. **ESLint Errors**: Check Aura/LWC JavaScript files for syntax issues
4. **Commit Message Rejected**: Ensure format matches `GH-XXXX: Description`

### Skip Hooks (Emergency Only)
```bash
# Skip pre-commit hook (NOT RECOMMENDED)
git commit --no-verify -m "GH-XXXX: Emergency commit"
```

## Integration with Development Workflow

This commit process integrates with:
- **GitHub Issues**: Commit messages reference issue numbers
- **Pull Requests**: Automated validation ensures code quality
- **CI/CD Pipelines**: Pre-validated commits reduce pipeline failures
- **Code Reviews**: Consistent formatting aids review process

## Related Documentation

- [COMMIT_CONVENTION.md](COMMIT_CONVENTION.md) - Detailed commit message rules
- [BRANCH_CONVENTION.md](BRANCH_CONVENTION.md) - Branch naming guidelines
- [README.md](README.md) - Project overview and setup
- [package.json](package.json) - Build