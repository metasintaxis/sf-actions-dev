/**
 * @file metadata-api-find-metadata-dependencies.js
 * @brief Summarizes error output from the dependency script in the GitHub Actions summary.
 *
 * @description
 *   Reads a JSON file produced by the dependency Bash script, extracts error information,
 *   and writes a formatted error summary table to the GitHub Actions summary using @actions/core.
 *
 * @usage
 *   node metadata-api-find-metadata-dependencies.js <dependencies.json>
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
	return data.error || {};
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
		['Error Code', error.code || 'UNKNOWN_ERROR'],
		['Message', error.message || 'No error message provided.'],
		['Details', error.details || '']
	];
}

/**
 * Writes the error summary using core.summary.
 * @param {object} error
 */
export async function writeErrorSummary(error) {
	await core.summary
		.addHeading('Dependency Script Error Report')
		.addTable(formatErrorTable(error))
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
