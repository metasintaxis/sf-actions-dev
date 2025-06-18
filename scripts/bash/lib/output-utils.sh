#!/bin/bash

#------------------------------------------------------------------------------
# /**
#  * @file output-utils.sh
#  * @module output-utils
#  * @version 0.1.1
#  * @author metasintaxis
#  * @license GPL-3.0
#  * @description
#  *   Provides functions for standardized CLI script output (block and JSON formats)
#  *   according to the CLI Output Specification v0.1.1.
#  *   Includes support for error reporting with traceability fields.
#  */
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# /**
#  * Generate an ISO 8601 UTC timestamp.
#  * @returns {string} ISO 8601 formatted UTC timestamp.
#  */
iso_timestamp() {
	date -u +"%Y-%m-%dT%H:%M:%SZ"
}

#------------------------------------------------------------------------------
# /**
#  * Check if a string is valid JSON (object or array).
#  * @param {string} $1 - The string to check.
#  * @returns {boolean} True if the string is valid JSON, false otherwise.
#  */
is_json() {
	[[ "$1" =~ ^\{.*\}$ || "$1" =~ ^\[.*\]$ ]]
}

#------------------------------------------------------------------------------
# /**
#  * Print a human-readable block for standard output.
#  * @param {string} $1 - Status (e.g., "OK").
#  * @param {string} $2 - Message.
#  * @param {string} $3 - Detail (may be JSON or plain text).
#  * @returns {void}
#  */
print_standard_block() {
	local status="$1"
	local message="$2"
	local detail="$3"
	local timestamp
	timestamp="$(iso_timestamp)"

	echo "Timestamp : $timestamp"
	echo "Status    : $status"
	echo "Message   : $message"
	if is_json "$detail"; then
		echo "Detail    :"
		echo "$detail" | jq .
	else
		echo "Detail    : $detail"
	fi
	echo "-------------------------------"
}

#------------------------------------------------------------------------------
# /**
#  * Print a JSON object for standard output.
#  * @param {string} $1 - Status (e.g., "OK").
#  * @param {string} $2 - Message.
#  * @param {string} $3 - Detail (may be JSON or plain text).
#  * @returns {void}
#  */
print_standard_json() {
	local status="$1"
	local message="$2"
	local detail="$3"
	local timestamp
	timestamp="$(iso_timestamp)"

	if is_json "$detail"; then
		jq -n \
			--arg status "$status" \
			--arg message "$message" \
			--arg timestamp "$timestamp" \
			--argjson detail "$detail" \
			'{status: $status, message: $message, detail: $detail, timestamp: $timestamp}'
	else
		jq -n \
			--arg status "$status" \
			--arg message "$message" \
			--arg detail "$detail" \
			--arg timestamp "$timestamp" \
			'{status: $status, message: $message, detail: $detail, timestamp: $timestamp}'
	fi
}

#------------------------------------------------------------------------------
# /**
#  * Print a human-readable block for error output.
#  * @param {string} $1 - Error message.
#  * @param {string} $2 - Error detail.
#  * @param {string} $3 - Error code.
#  * @param {int}    $4 - Line number.
#  * @param {string} $5 - Script filename.
#  * @param {string} $6 - Function name.
#  * @returns {void}
#  */
print_error_block() {
	local message="$1"
	local detail="$2"
	local errorCode="$3"
	local line="$4"
	local script="$5"
	local func="$6"
	local timestamp
	timestamp="$(iso_timestamp)"

	echo "Timestamp : $timestamp"
	echo "Status    : ERROR"
	echo "Message   : $message"
	[[ -n "$errorCode" ]] && echo "Error Code: $errorCode"
	[[ -n "$line" ]] && echo "Line      : $line"
	[[ -n "$script" ]] && echo "Script    : $script"
	[[ -n "$func" ]] && echo "Function  : $func"
	if is_json "$detail"; then
		echo "Detail    :"
		echo "$detail" | jq .
	else
		echo "Detail    : $detail"
	fi
	echo "-------------------------------"
}

#------------------------------------------------------------------------------
# /**
#  * Print a JSON object for error output.
#  * @param {string} $1 - Error message.
#  * @param {string} $2 - Error detail.
#  * @param {string} $3 - Error code.
#  * @param {int}    $4 - Line number.
#  * @param {string} $5 - Script filename.
#  * @param {string} $6 - Function name.
#  * @returns {void}
#  */
print_error_json() {
	local message="$1"
	local detail="$2"
	local errorCode="$3"
	local line="$4"
	local script="$5"
	local func="$6"
	local timestamp
	timestamp="$(iso_timestamp)"

	if is_json "$detail"; then
		jq -n \
			--arg status "ERROR" \
			--arg message "$message" \
			--arg timestamp "$timestamp" \
			--arg errorCode "$errorCode" \
			--argjson detail "$detail" \
			--argjson line "${line:-null}" \
			--arg script "$script" \
			--arg func "$func" \
			'{
        status: $status,
        message: $message,
        detail: $detail,
        timestamp: $timestamp,
        errorCode: ($errorCode // null),
        line: ($line // null),
        script: ($script // null),
        function: ($func // null)
      }'
	else
		jq -n \
			--arg status "ERROR" \
			--arg message "$message" \
			--arg detail "$detail" \
			--arg timestamp "$timestamp" \
			--arg errorCode "$errorCode" \
			--argjson line "${line:-null}" \
			--arg script "$script" \
			--arg func "$func" \
			'{
        status: $status,
        message: $message,
        detail: $detail,
        timestamp: $timestamp,
        errorCode: ($errorCode // null),
        line: ($line // null),
        script: ($script // null),
        function: ($func // null)
      }'
	fi
}
