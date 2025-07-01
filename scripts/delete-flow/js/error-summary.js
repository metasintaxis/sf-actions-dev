/**
 * @file error-summary.js
 * @brief Summarizes error output from the delete-flow script in the GitHub Actions summary.
 *
 * @description
 *   Reads a JSON file produced by the delete-flow Bash script, extracts error information,
 *   and writes a formatted error summary table to the GitHub Actions summary using @actions/core.
 *
 * @usage
 *   node error-summary.js <delete-flow-report.json>
 */

import fs from 'fs';
import * as core from '@actions/core';

/**
 * Reads and parses the error object from the given JSON file.
 * @param {string} filePath
 * @returns {object} error object
 */
export function readError(filePath) {
	const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
	const detail = data.detail || {};
	return {
		status: data.status,
		message: data.message,
		errorCode: data.errorCode,
		line: data.line,
		script: data.script,
		function: data.function,
		timestamp: data.timestamp,
		// Flatten some detail fields if present
		detailName: detail.name,
		detailMessage: detail.message,
		detailErrorCode: detail.errorCode,
		detailContext: detail.context,
		detailStack: detail.stack,
		detailWarnings: detail.warnings,
		detailStatus: detail.status,
		detailCommandName: detail.commandName,
		detailExitCode: detail.exitCode
	};
}

/**
 * Formats the error as a table for the summary.
 * @param {object} error
 * @returns {Array<Array<{data: string, header?: boolean}>>}
 */
export function formatErrorTable(error) {
	return [
		[
			{ data: 'Field', header: true },
			{ data: 'Value', header: true }
		],
		['Status', error.status || ''],
		[
			'Error Code',
			error.errorCode ||
				error.detailErrorCode ||
				'UNKNOWN_ERROR'
		],
		[
			'Message',
			error.message ||
				error.detailMessage ||
				'No error message provided.'
		],
		['Detail Name', error.detailName || ''],
		['Detail Context', error.detailContext || ''],
		['Script', error.script || ''],
		['Function', error.function || ''],
		['Line', error.line != null ? String(error.line) : ''],
		['Timestamp', error.timestamp || ''],
		[
			'Stack',
			error.detailStack
				? error.detailStack.length > 500
					? error.detailStack.slice(0, 500) +
						'...'
					: error.detailStack
				: ''
		]
	];
}

/**
 * Writes the error summary using core.summary.
 * @param {object} error
 */
export async function writeErrorSummary(error) {
	await core.summary
		.addHeading('❌ Flow Deletion Error Report')
		.addTable(formatErrorTable(error))
		.addBreak()
		.addRaw('### Troubleshooting Tips')
		.addList([
			'Check if the flow developer name exists in the target org',
			'Verify the flow status is correct (Obsolete, Draft, Active, InvalidDraft)',
			'Ensure you have sufficient permissions to delete flow versions',
			'Check the script logs for more detailed error information'
		])
		.write();
}

const main = async () => {
	const filePath = process.argv[2];
	if (!filePath) {
		core.setFailed('No input file specified.');
		process.exit(1);
	}
	if (!fs.existsSync(filePath)) {
		core.setFailed(`File not found: ${filePath}`);
		process.exit(1);
	}
	const error = readError(filePath);
	await writeErrorSummary(error);
};

main().catch((err) => {
	core.setFailed(`Action failed with error: ${err}`);
});
