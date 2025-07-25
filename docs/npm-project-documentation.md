# NPM Tooling Configuration for SFDX

## Project Overview

This is a **Salesforce DX (SFDX) project** structured as an **NPM package** to leverage modern JavaScript tooling and development workflows. The project combines Salesforce development capabilities with NPM's dependency management and script automation.

### Project Type

- **Primary**: Salesforce DX project for Lightning Web Components (LWC) and Aura components
- **Secondary**: NPM project for tooling, automation, and development workflow management

## Package.json Configuration

### Basic Information

```json
{
  "name": "sf-actions-dev",
  "private": true,
  "version": "0.0.1",
  "description": "Repository to store GitHub actions and automation scripts to work with salesforce instances.",
  "type": "module"
}
```

- **Name**: `sf-actions-dev` - Identifies the project
- **Private**: `true` - Prevents accidental publication to NPM registry
- **Version**: `0.0.1` - Semantic versioning for internal tracking
- **Type**: `module` - Enables ES6 module syntax support

## NPM Scripts

### Code Quality & Formatting

| Script | Command | Purpose |
|--------|---------|---------|
| `lint` | `eslint **/{aura,lwc}/**/*.js` | Lints JavaScript files in Aura and LWC components |
| `prettier` | `prettier --write "**/*.{cls,cmp,component,css,html,js,json,md,page,trigger,xml,yaml,yml}"` | Formats all supported Salesforce and web files |
| `prettier:verify` | `prettier --check "**/*.{cls,cmp,component,css,html,js,json,md,page,trigger,xml,yaml,yml}"` | Checks if files are properly formatted (CI/CD ready) |

### Testing

| Script | Command | Purpose |
|--------|---------|---------|
| `test` | `npm run test:unit` | Runs all unit tests (alias) |
| `test:unit` | `sfdx-lwc-jest` | Executes LWC unit tests using Salesforce's Jest preset |
| `test:unit:watch` | `sfdx-lwc-jest --watch` | Runs tests in watch mode for development |
| `test:unit:debug` | `sfdx-lwc-jest --debug` | Runs tests with debugging enabled |
| `test:unit:coverage` | `sfdx-lwc-jest --coverage` | Generates test coverage reports |

### Git Hooks & Automation

| Script | Command | Purpose |
|--------|---------|---------|
| `postinstall` | `husky init` | Automatically sets up Git hooks after npm install |
| `precommit` | `lint-staged` | Runs pre-commit validations (triggered by Husky) |
| `prepare` | `husky` | Ensures Husky is properly configured |

## Dependencies

### Salesforce-Specific Dependencies

#### LWC (Lightning Web Components)

- `@lwc/engine-dom` - LWC runtime engine for DOM operations
- `@lwc/jest-preset` - Jest configuration for LWC testing
- `@salesforce/sfdx-lwc-jest` - Salesforce's Jest testing framework for LWC

#### ESLint Configuration

- `@salesforce/eslint-config-lwc` - Official Salesforce ESLint rules for LWC
- `@salesforce/eslint-plugin-aura` - ESLint rules for Aura components
- `@salesforce/eslint-plugin-lightning` - ESLint rules for Lightning platform
- `@lwc/eslint-plugin-lwc` - Core LWC ESLint plugin

### Development Tooling

#### Code Formatting

- `prettier` - Code formatter
- `@prettier/plugin-xml` - XML formatting support
- `prettier-plugin-apex` - Apex code formatting
- `prettier-plugin-sh` - Shell script formatting

#### Linting & Testing

- `eslint` - JavaScript linter
- `eslint-plugin-import` - Import/export linting
- `eslint-plugin-jest` - Jest-specific linting rules
- `jest` - JavaScript testing framework

#### Git Workflow

- `husky` - Git hooks management
- `lint-staged` - Run linters on staged files only

## Lint-Staged Configuration

```json
{
  "**/*.{cls,cmp,component,css,html,js,json,md,page,trigger,xml,yaml,yml}": [
    "prettier --write"
  ],
  "**/{aura,lwc}/**/*.js": [
    "eslint"
  ]
}
```

### File Pattern Targeting

- **All supported files**: Prettier formatting for Salesforce files (.cls, .cmp, .component, .trigger) and web files
- **Component JavaScript**: ESLint validation specifically for Aura and LWC JavaScript files

## Why NPM for Salesforce DX?

1. **Modern Tooling**: Access to industry-standard JavaScript development tools
2. **Dependency Management**: Centralized management of development dependencies
3. **Script Automation**: Standardized commands across development teams
4. **Git Hooks**: Automated code quality enforcement
5. **CI/CD Integration**: NPM scripts work seamlessly with build pipelines
6. **Developer Experience**: Familiar workflow for JavaScript developers

## Usage

```bash
# Install all dependencies and set up Git hooks
npm install

# Format code
npm run prettier

# Run tests
npm run test

# Lint components
npm run lint

# Check formatting (CI/CD)
npm run prettier:verify
```

This configuration ensures that Salesforce development follows modern JavaScript best practices while maintaining platform-specific requirements.