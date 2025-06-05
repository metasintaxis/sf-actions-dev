/**
 * @file metadata-api-find-metadata-dependencies-error-summary.js
 * @brief Summarizes error output from the dependency script in the GitHub Actions summary.
 *
 * @usage
 *   node metadata-api-find-metadata-dependencies-error-summary.js <dependencies.json>
 */

import fs from 'fs';
import * as core from '@actions/core';

function summarizeError(filePath) {
	const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
	const error = data.error || {};
	const code = error.code || 'UNKNOWN_ERROR';
	const message = error.message || 'No error message provided.';
	const details = error.details || '';

	let summary = `❌ **Dependency Script Failed**\n\n`;
	summary += `**Error Code:** \`${code}\`\n\n`;
	summary += `**Message:** ${message}\n\n`;
	if (details) {
		summary += `**Details:**\n\n\`\`\`\n${details}\n\`\`\`\n`;
	}

	return summary;
}

const filePath = process.argv[2];
if (!filePath) {
	core.setFailed('No input file specified.');
	process.exit(1);
}
if (!fs.existsSync(filePath)) {
	core.setFailed(`File not found: ${filePath}`);
	process.exit(1);
}

const summary = summarizeError(filePath);
await core.summary.addRaw(summary, true).write();
