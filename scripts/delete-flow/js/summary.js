/**
 * @file summary.js
 * @brief Summarizes Salesforce flow deletion results as a GitHub Actions summary table.
 *
 * @description
 *   Reads a JSON file produced by the delete-flow Bash script, extracts deletion information,
 *   and writes a formatted summary table to the GitHub Actions summary using @actions/core.
 *
 * @usage
 *   node summary.js <delete-flow-report.json>
 */

import fs from 'fs';
import * as core from '@actions/core';

/**
 * Reads and parses the flow deletion JSON file.
 * @param {string} filePath
 * @returns {object}
 */
export const readDeletionReport = (filePath) => {
	try {
		const content = fs.readFileSync(filePath, 'utf8').trim();
		
		// Handle case where there might be multiple JSON objects
		const lines = content.split('\n').filter(line => line.trim());
		
		if (lines.length === 0) {
			throw new Error('File is empty');
		}
		
		if (lines.length === 1) {
			// Single JSON object
			return JSON.parse(lines[0]);
		}
		
		// Multiple lines - try to find the last valid JSON object
		// (assuming the final result is what we want)
		for (let i = lines.length - 1; i >= 0; i--) {
			try {
				const parsed = JSON.parse(lines[i]);
				if (parsed.status && parsed.message) {
					return parsed;
				}
			} catch (e) {
				// Skip invalid JSON lines
				continue;
			}
		}
		
		// If no valid JSON found, try parsing the entire content
		return JSON.parse(content);
	} catch (error) {
		throw new Error(`Failed to parse JSON from ${filePath}: ${error.message}`);
	}
};

/**
 * Builds the table data for deleted flow versions.
 * @param {object} deletionReport
 * @returns {Array<Array<{data: string, header?: boolean}>>}
 */
export const buildDeletionTableData = (deletionReport) => {
	let detail;
	try {
		// If detail is already an object, use it; if it's a string, parse it
		detail = typeof deletionReport?.detail === 'string' 
			? JSON.parse(deletionReport.detail) 
			: deletionReport?.detail || {};
	} catch (error) {
		console.warn('Failed to parse detail field:', error.message);
		detail = {};
	}
	
	const records = detail?.records || [];
	const tableHeader = [
		{ data: 'Flow ID', header: true },
		{ data: 'Version Number', header: true }
	];
	const tableData = [tableHeader];

	for (const record of records) {
		tableData.push([
			{ data: record.id || '' },
			{ data: record.versionNumber?.toString() || '' }
		]);
	}
	return tableData;
};

/**
 * Extracts summary information from the deletion report.
 * @param {object} deletionReport
 * @returns {object}
 */
export const extractSummaryInfo = (deletionReport) => {
	let detail;
	try {
		// If detail is already an object, use it; if it's a string, parse it
		detail = typeof deletionReport?.detail === 'string' 
			? JSON.parse(deletionReport.detail) 
			: deletionReport?.detail || {};
	} catch (error) {
		console.warn('Failed to parse detail field:', error.message);
		detail = {};
	}
	
	return {
		deletedCount: detail?.deletedRecords || 0,
		records: detail?.records || [],
		message: deletionReport?.message || 'Flow deletion completed',
		status: deletionReport?.status || 'OK'
	};
};

/**
 * Writes the flow deletion summary to the GitHub Actions summary.
 * @param {Array} deletionTableData
 * @param {object} deletionReport
 * @param {object} summaryInfo
 */
export const writeDeletionSummary = async (
	deletionTableData,
	deletionReport,
	summaryInfo
) => {
	const DELETION_REPORT_HEADING = '🗑️ Flow Deletion Results';
	const { deletedCount, records } = summaryInfo;

	await core.summary
		.addHeading(DELETION_REPORT_HEADING)
		.addHeading('Summary', 3)
		.addRaw(`<b>Total Deleted Versions:</b> ${deletedCount}`)
		.addBreak()
		.addRaw(`<b>Status:</b> ${summaryInfo.status}`)
		.addBreak();

	if (deletedCount > 0) {
		await core.summary
			.addHeading('✅ Deleted Flow Versions', 3)
			.addTable(deletionTableData)
			.addBreak()
			.addRaw('### 🎉 Success!')
			.addRaw(`Successfully deleted **${deletedCount}** flow version(s).`);
	} else {
		await core.summary
			.addHeading('ℹ️ No Versions Found', 3)
			.addRaw('No flow versions found matching the specified criteria.');
	}

	if (deletionReport?.timestamp) {
		await core.summary
			.addBreak()
			.addRaw(
				`<sub>Report generated: ${deletionReport.timestamp}</sub>`
			);
	}

	await core.summary.write();
};

/**
 * Main execution function.
 */
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
	
	// Debug: Show raw file contents
	try {
		const rawContent = fs.readFileSync(filePath, 'utf8');
		console.log('Raw file contents:');
		console.log(rawContent);
		console.log('--- End raw contents ---');
	} catch (error) {
		core.setFailed(`Failed to read file: ${error.message}`);
		process.exit(1);
	}
	
	const deletionReport = readDeletionReport(filePath);
	const summaryInfo = extractSummaryInfo(deletionReport);
	const deletionTableData = buildDeletionTableData(deletionReport);
	
	await writeDeletionSummary(deletionTableData, deletionReport, summaryInfo);
};

main().catch((err) => {
	core.setFailed(`Action failed with error: ${err}`);
});
