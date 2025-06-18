#!/bin/bash

# CLI Output Specification Library v0.1.1
# Author: metasintaxis
# Provides functions for standardized CLI script output (block and JSON formats).

#------------------------------------------------------------------------------
# Generate an ISO 8601 UTC timestamp
iso_timestamp() {
	date -u +"%Y-%m-%dT%H:%M:%SZ"
}

#------------------------------------------------------------------------------
# Check if a string is valid JSON (object or array)
# Usage: is_json "$string"
is_json() {
	[[ "$1" =~ ^\{.*\}$ || "$1" =~ ^\[.*\]$ ]]
}

#------------------------------------------------------------------------------
# Print a human-readable block for standard output
# Usage: print_standard_block <status> <message> <detail>
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
# Print a JSON object for standard output
# Usage: print_standard_json <status> <message> <detail>
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
# Print a human-readable block for error output
# Usage: print_error_block <message> <detail> <errorCode> <line> <script> <function>
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
# Print a JSON object for error output
# Usage: print_error_json <message> <detail> <errorCode> <line> <script> <function>
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
