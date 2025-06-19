# CLI Output Specification

This document establishes a standardized structure for both standard and error outputs from CLI scripts. The specification ensures outputs are consistent, robust, and easily parsed by both humans and machines. It is designed to support automation, traceability, and interoperability in industrial environments where reliability and auditability are essential.

---

## Specification Metadata

| Property   | Value                       |
|------------|-----------------------------|
| **Title**      | CLI Output Specification     |
| **Version**    | 0.1.1                         |
| **Date**       | 2025-06-17                    |
| **Author**     | metasintaxis                  |
| **License**    | MIT                           |
| **Scope**      | CLI script output formatting  |
| **Purpose**    | To define a unified, extensible, and machine/human-friendly output structure for CLI scripts, supporting both interactive use and automated pipelines in demanding environments. |

---

## Standard Output Schema

All script outputs—whether standard or error—must use the following fields for consistency, traceability, and ease of parsing:

| Field        | Type    | Required | Notes                                                                 |
|--------------|---------|----------|-----------------------------------------------------------------------|
| `status`     | string  | Yes      | `OK`, `WARNING`, or `ERROR`                                           |
| `message`    | string  | Yes      | Human-readable summary                                                |
| `detail`     | any     | No       | Main result, extra context, or error details (can be any type, e.g., JSON) |
| `timestamp`  | string  | Yes      | ISO 8601 format (e.g., `2025-06-17T19:12:10Z`)                        |
| `errorCode`  | string  | No       | Error identifier, present only for errors                             |
| `line`       | int     | No       | Line number where the error occurred (errors only, recommended)       |
| `script`     | string  | No       | Script filename (errors only, recommended)                            |
| `function`   | string  | No       |  Name of the function where the output or error originated (errors only, recommended) |

- **Note:** The `detail` field is generic and may contain any relevant data, including embedded JSON from other commands, error stack traces, or additional context.
- The `line`, `script`, and `function` fields are recommended for error outputs to aid diagnostics and traceability.

---

## Human-Readable Block Output

Scripts **must** emit a human-friendly block format for interactive use.  
If the `detail` field contains complex or multi-line data (such as JSON), it should be pretty-printed and indented for clarity.

**Example (simple detail):**
```
Timestamp : 2025-06-16T12:00:00Z
Status    : OK
Message   : Operation completed
Detail    : 42
-------------------------------
```

**Example (complex detail):**
```
Timestamp : 2025-06-17T19:12:10Z
Status    : OK
Message   : Fetched org info
Detail    :
{
  "orgId": "00D...",
  "username": "user@example.com"
}
-------------------------------
```

**Example (error):**
```
Timestamp : 2025-06-16T12:01:00Z
Status    : ERROR
Message   : Invalid input
Detail    : Missing 'name' field
Error Code: E001
Line      : 42
Script    : my-script.sh
Function  : validate_args
-------------------------------
```

---

## JSON Output Example

```json
{
  "status": "OK",
  "message": "Operation completed",
  "detail": 42,
  "timestamp": "2025-06-16T12:00:00Z"
}
```

### JSON Output Example with Embedded Object

```json
{
  "status": "OK",
  "message": "Fetched org info",
  "detail": {
    "orgId": "00D...",
    "username": "user@example.com"
  },
  "timestamp": "2025-06-17T19:12:10Z"
}
```

### JSON Error Output Example

```json
{
  "status": "ERROR",
  "message": "Invalid input",
  "detail": "Missing 'name' field",
  "timestamp": "2025-06-16T12:01:00Z",
  "errorCode": "E001",
  "line": 42,
  "script": "my-script.sh",
  "function": "validate_args"
}
```

---

## Security, Traceability, and Reliability Considerations

- **Timestamps** must always be in UTC and ISO 8601 format for auditability.
- **Error reporting** should always include `line`, `script`, and `function` when possible for traceability.
- **Field presence**: Required fields must always be present; optional fields should be set to `null` or omitted if not applicable.
- **Data integrity**: Scripts must ensure that output is well-formed and valid JSON when using machine-readable output.
- **No sensitive data**: Do not include secrets, credentials, or classified information in any output field.

---

## Versioning and Compatibility

- The specification is **versioned** for stability and future enhancements.
- Backward compatibility must be maintained across `x.0` versions.
- New fields or formats must be introduced as optional and documented clearly.
- Breaking changes require a major or minor version bump.

---

## Best Practices

- Always include `status`, `message`, and `timestamp`.
- Use `detail` for both result data and error context, including embedded JSON.
- Set unused fields to `null` or omit them.
- Use `errorCode`, `line`, `script`, and `function` only for errors.
- Scripts must support both JSON and human-readable block output.
- When reporting errors, use Bash’s `${LINENO}`, `${BASH_SOURCE[0]}`, and `${FUNCNAME[0]}` to populate `line`, `script`, and `function`.
- Validate output format in CI/CD pipelines for mission-critical environments.

---

## Next Steps

Future enhancements may include:

- Field-level data classification labels
- Integration examples in Bash, Python, or Node.js
- Guidelines for log aggregation, schema validation, and compliance
- Recommendations for internationalization and localization