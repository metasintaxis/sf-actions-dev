# Monitor: Code Quality Workflow 

## Overview

This documentation covers the **Monitor: Code Quality** GitHub Actions workflow, which provides comprehensive code quality monitoring for Salesforce repositories using the Salesforce Code Analyzer with configurable analysis engines.

---

## Purpose

The Monitor: Code Quality workflow allows you to:

- Perform on-demand code quality analysis across your Salesforce repository
- Target specific folders or scan the entire codebase
- Execute different analysis engines (PMD, ESLint, Flow analysis, etc.)
- Generate detailed reports in multiple formats (HTML, JSON, SARIF)
- Integrate with GitHub Security tab for vulnerability tracking
- Maintain code quality standards through automated analysis

---

## Workflow Location

**File**: `.github/workflows/monitor-code-quality.yml`

**Trigger**: Manual workflow dispatch only (workflow_dispatch)

---

## Configuration

### Workflow Inputs

| Parameter | Type | Default | Required | Description | Options |
|-----------|------|---------|----------|-------------|---------|
| `target_folder` | string | `force-app` | No | Target folder to scan | Any valid directory path |
| `rule_selector` | choice | `all` | No | Rule engines to apply | `all`, `cpd`, `eslint`, `flow`, `pmd`, `retire-js`, `regex`, `sfge` |

### Dynamic Run Naming

The workflow uses dynamic run names for easy identification:

```text
Monitor - Code Quality: Running Over {target_folder} With {rule_selector} Rules
```

**Example**: `Monitor - Code Quality: Running Over force-app With pmd Rules`

---

## Analysis Engines

### Available Rule Selectors

| Engine | Purpose | Technology Focus | Use Cases |
|--------|---------|------------------|-----------|
| **all** | Complete analysis suite | All engines combined | Comprehensive quality assessment |
| **cpd** | Copy-Paste Detection | Duplicate code identification | Code deduplication efforts |
| **eslint** | JavaScript/LWC Linting | Lightning Web Components | Frontend code quality |
| **flow** | Salesforce Flow Analysis | Flow best practices | Process automation quality |
| **pmd** | Static Code Analysis | Apex code quality | Backend code analysis |
| **retire-js** | Security Vulnerabilities | JavaScript dependency scanning | Security assessments |
| **regex** | Pattern Matching | Custom regex rules | Custom rule validation |
| **sfge** | Salesforce Graph Engine | Advanced flow analysis | Complex flow dependencies |

---

## Usage

### Option 1: GitHub Actions UI

1. Navigate to **Actions** tab in your GitHub repository
2. Select **"Monitor: Code Quality"** workflow
3. Click **"Run workflow"**
4. Configure parameters:
   - **Target folder to scan**: e.g., `force-app` or `force-app/main/default/classes`
   - **Rule selector to apply**: Select from dropdown menu
5. Click **"Run workflow"**

### Option 2: GitHub CLI

```bash
# Full repository scan with all rules
gh workflow run monitor-code-quality.yml \
  -f target_folder="force-app" \
  -f rule_selector="all"

# Apex classes only with PMD analysis
gh workflow run monitor-code-quality.yml \
  -f target_folder="force-app/main/default/classes" \
  -f rule_selector="pmd"

# LWC components with ESLint
gh workflow run monitor-code-quality.yml \
  -f target_folder="force-app/main/default/lwc" \
  -f rule_selector="eslint"
```

---

## Workflow Process

### 1. Environment Setup

```yaml
- Checkout source code (full git history)
- Setup Node.js >=20.9.0 with npm caching
- Setup Java >=11 (Zulu distribution)
- Setup Python >=3.10
- Install Salesforce CLI
- Install Code Analyzer plugin
```

### 2. Validation and Configuration

```yaml
- Validate target folder exists
- Sanitize folder paths for artifact naming
- Generate timestamps for unique file naming
- Display scan configuration in GitHub summary
```

### 3. Code Analysis Execution

```yaml
- Execute Salesforce Code Analyzer with specified parameters
- Generate HTML and JSON reports with timestamped names
- Create SARIF output for GitHub Security integration
- Upload artifacts with descriptive names
```

### 4. Quality Gate Evaluation

```yaml
- Check violation thresholds
- Fail workflow if criteria exceeded:
  * Exit code > 0 (analyzer errors)
  * Any Severity 1 violations (critical)
  * Any Severity 2 violations (major)
  * More than 10 total violations (volume)
```

---

## Outputs and Artifacts

### Generated Files

The workflow creates timestamped files for easy identification:

```text
code-quality-report-{sanitized-folder}-{rule-selector}-{timestamp}.html
code-quality-report-{sanitized-folder}-{rule-selector}-{timestamp}.json
```

**Examples**:

```text
code-quality-report-force-app-pmd-20250726-143022.html
code-quality-report-force-app-main-default-classes-eslint-20250726-144530.json
```

### Artifact Organization

Artifacts are uploaded with descriptive names:

```text
code-quality-results-{sanitized-folder}-{rule-selector}
```

**Examples**:

```text
code-quality-results-force-app-all
code-quality-results-force-app-main-default-lwc-eslint
```

### GitHub Integration

- **SARIF Upload**: Automatic integration with GitHub Security tab
- **Workflow Summary**: Configuration details and scan parameters
- **Security Alerts**: Vulnerability findings appear in Security tab
- **Downloadable Reports**: HTML and JSON artifacts for detailed analysis

---

## Use Cases and Examples

### 1. Comprehensive Repository Audit

```yaml
Target Folder: force-app
Rule Selector: all
```

**Purpose**: Complete code quality assessment for periodic audits

### 2. Apex Code Analysis

```yaml
Target Folder: force-app/main/default/classes
Rule Selector: pmd
```

**Purpose**: Focused static analysis on Apex classes

### 3. Lightning Web Components Quality

```yaml
Target Folder: force-app/main/default/lwc
Rule Selector: eslint
```

**Purpose**: JavaScript linting and best practices for LWC

### 4. Security Vulnerability Assessment

```yaml
Target Folder: force-app
Rule Selector: retire-js
```

**Purpose**: Identify security vulnerabilities in JavaScript dependencies

### 5. Flow Process Analysis

```yaml
Target Folder: force-app/main/default/flows
Rule Selector: flow
```

**Purpose**: Salesforce Flow best practices and optimization

### 6. Duplicate Code Detection

```yaml
Target Folder: force-app/main/default/classes
Rule Selector: cpd
```

**Purpose**: Identify copy-paste code for refactoring opportunities

---

## Quality Thresholds

### Workflow Failure Conditions

The workflow fails when **any** of these conditions are met:

| Condition | Threshold | Severity | Action |
|-----------|-----------|----------|---------|
| Analyzer Exit Code | > 0 | Critical | Immediate failure |
| Severity 1 Violations | > 0 | Critical | Immediate failure |
| Severity 2 Violations | > 0 | Major | Immediate failure |
| Total Violations | > 10 | Volume | Immediate failure |

### Severity Level Definitions

- **Severity 1**: Critical issues requiring immediate attention (security, major bugs)
- **Severity 2**: Major issues affecting code quality (performance, maintainability)
- **Severity 3**: Minor issues and suggestions (style, optimization hints)

---

## Technical Requirements

### Runtime Dependencies

| Component | Version | Purpose |
|-----------|---------|---------|
| **Node.js** | >=20.9.0 | JavaScript runtime and npm package management |
| **Java** | >=11 | PMD static analysis and Apex code processing |
| **Python** | >=3.10 | Additional tooling and utility support |
| **Salesforce CLI** | Latest | Core Salesforce development tools |
| **Code Analyzer Plugin** | Latest | Salesforce-specific analysis engines |

### GitHub Permissions

```yaml
contents: read        # Repository checkout access
actions: read         # Workflow execution context
security-events: write # SARIF upload for Security tab
```

### System Requirements

- **Ubuntu Latest**: Workflow runner environment
- **Git**: Full repository history access (fetch-depth: 0)
- **Disk Space**: Sufficient for analysis artifacts and reports

---

## File Organization Strategy

### Target Folder Patterns

```bash
# Recommended folder patterns for focused analysis

# Full Application
force-app

# Specific Component Types
force-app/main/default/classes          # Apex classes
force-app/main/default/triggers         # Apex triggers
force-app/main/default/lwc              # Lightning Web Components
force-app/main/default/aura             # Aura components
force-app/main/default/flows            # Salesforce Flows

# Package-Based Organization
force-app/main/default/classes/controllers
force-app/main/default/classes/services
force-app/main/default/classes/utilities
```

### Artifact Naming Convention

The workflow automatically sanitizes folder paths for artifact names:

| Input Folder | Sanitized Name | Artifact Name |
|--------------|----------------|---------------|
| `force-app` | `force-app` | `code-quality-results-force-app-pmd` |
| `force-app/main/default/classes` | `force-app-main-default-classes` | `code-quality-results-force-app-main-default-classes-pmd` |
| `src/classes` | `src-classes` | `code-quality-results-src-classes-eslint` |

---

## Troubleshooting

### Common Issues

#### 1. Target Folder Not Found

```bash
Target folder 'invalid-path' does not exist
Available folders:
./force-app
./force-app/main
./force-app/main/default
```

**Solution**:

- Verify folder path exists in repository
- Use suggested folders from error output
- Check for case sensitivity

#### 2. No Code to Analyze

```bash
No files found for analysis in target folder
```

**Solution**:

- Ensure target folder contains relevant source files
- Verify rule selector matches file types in folder
- Check file permissions and accessibility

#### 3. Quality Gate Failures

```bash
Code quality gate failed:
Exit code: 0
Severity 1 violations: 2
Severity 2 violations: 5
Total violations: 15
```

**Solution**:

- Review detailed HTML/JSON reports in artifacts
- Address critical (Severity 1) violations first
- Consider adjusting quality thresholds if appropriate
- Implement code improvements based on findings

#### 4. Analysis Engine Errors

```bash
Error: PMD analysis failed
```

**Solution**:

- Verify Java setup and version compatibility
- Check for Apex syntax errors in target files
- Review Code Analyzer plugin installation
- Examine detailed error logs in workflow output

---

## Best Practices

### 1. Monitoring Strategy

#### Frequency Recommendations

- **Weekly**: Full repository scans (`all` rules) for comprehensive health checks
- **On-demand**: Targeted analysis before major releases
- **Component-specific**: Regular analysis of frequently modified areas
- **Security-focused**: Monthly vulnerability scans (`retire-js`)

#### Progressive Analysis Approach

```bash
1. Start with specific rule selectors (pmd, eslint)
2. Address critical violations before running full analysis
3. Gradually expand to comprehensive scans (all)
4. Establish baseline quality metrics
```

### 2. Team Workflow Integration

#### Development Process

- Run targeted analysis before code reviews
- Use component-specific scans during feature development
- Perform comprehensive analysis before release candidates
- Establish quality gates for deployment pipelines

#### Collaboration Patterns

- Share artifact reports with team members
- Use GitHub Security tab for vulnerability tracking
- Document quality improvement initiatives
- Set team-wide quality standards and thresholds

### 3. Report Management

#### Artifact Organization

- Download and archive important analysis reports
- Compare results across different time periods
- Track quality metrics and improvement trends
- Maintain documentation of resolved violations

#### Analysis Review Process

- Prioritize Severity 1 violations for immediate action
- Plan Severity 2 violations for upcoming sprints
- Use Severity 3 violations for continuous improvement
- Establish team review cycles for quality reports

---

## Integration Points

### GitHub Security Tab

- **SARIF Integration**: Automatic upload of security findings
- **Vulnerability Tracking**: Centralized security issue management
- **Alert Management**: Configure notifications for new vulnerabilities
- **Historical Tracking**: Monitor security improvements over time

### Development Workflow

- **Pre-merge Analysis**: Quality checks before code integration
- **Release Validation**: Comprehensive analysis before deployment
- **Continuous Monitoring**: Regular quality health checks
- **Technical Debt Management**: Systematic improvement planning

### CI/CD Pipeline Integration

- **Quality Gates**: Fail builds on critical violations
- **Automated Reporting**: Generate quality reports for stakeholders
- **Trend Analysis**: Track quality metrics over time
- **Deployment Decisions**: Use quality data for release planning

---

## Advanced Usage Scenarios

### 1. Multi-Component Analysis Pipeline

```bash
# Sequence of targeted analyses
1. Run ESLint on LWC components
2. Run PMD on Apex classes
3. Run Flow analysis on automation
4. Run comprehensive scan for final validation
```

### 2. Security-Focused Monitoring

```bash
# Security vulnerability assessment workflow
1. Run retire-js for JavaScript dependencies
2. Run PMD with security-focused rules
3. Review SARIF results in GitHub Security tab
4. Plan remediation based on severity levels
```

### 3. Performance-Focused Analysis

```bash
# Performance optimization workflow
1. Run PMD analysis for performance patterns
2. Run CPD for code duplication identification
3. Analyze reports for optimization opportunities
4. Implement improvements and re-analyze
```

---

## Related Workflows

This workflow complements other repository automation:

- **CI/CD Pipelines**: Quality validation before deployment
- **Pull Request Validation**: Code quality checks on feature branches
- **Security Monitoring**: Vulnerability assessment and tracking
- **Documentation Generation**: Quality metrics for project reporting

---

## Monitoring and Metrics

### Key Performance Indicators

| Metric | Description | Target |
|--------|-------------|--------|
| **Total Violations** | Overall code quality issues | < 10 per scan |
| **Severity 1 Count** | Critical violations | 0 |
| **Severity 2 Count** | Major violations | 0 |
| **Analysis Coverage** | Percentage of code analyzed | 100% |
| **Scan Duration** | Time to complete analysis | < 5 minutes |

### Quality Trends

Track improvements over time:

- Violation count reduction
- Severity distribution changes
- Code coverage improvements
- Security vulnerability trends

---

## Support and Resources

### Getting Help

1. **Check Workflow Logs**: Detailed execution information in GitHub Actions
2. **Review Artifacts**: Download HTML/JSON reports for detailed analysis
3. **Consult Documentation**: Salesforce Code Analyzer official documentation
4. **Team Collaboration**: Share findings with development team
5. **GitHub Issues**: Report workflow problems or enhancement requests

### External Resources

- [Salesforce Code Analyzer Documentation](https://forcedotcom.github.io/sfdx-scanner/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/)
- [PMD Rules Reference](https://pmd.github.io/latest/pmd_rules_apex.html)
- [ESLint Rules Documentation](https://eslint.org/docs/rules/)

---

## Change Log

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-07-26 | Initial release with configurable analysis engines |
| 1.1 | 2025-07-26 | Added dynamic file naming and artifact organization |
| 1.2 | 2025-07-26 | Enhanced GitHub Security integration and SARIF upload |

---

## Additional Information

### Workflow Maintenance

- **Regular Updates**: Keep Salesforce CLI and Code Analyzer plugin current
- **Rule Customization**: Consider custom PMD rulesets for organization-specific needs
- **Threshold Adjustment**: Monitor and adjust quality gate thresholds based on team needs
- **Performance Optimization**: Regular review of scan duration and resource usage

### Future Enhancements

Potential improvements for future versions:

- **Scheduled Execution**: Automated periodic scans
- **Custom Rule Configuration**: Organization-specific rule sets
- **Notification Integration**: Slack/Teams alerts for quality issues
- **Trend Dashboards**: Historical quality metrics visualization
- **Multi-Environment**: Comparative analysis across different orgs

---

**Note: This workflow provides comprehensive code quality monitoring. Use the insights to drive continuous improvement in your Salesforce development practices.**