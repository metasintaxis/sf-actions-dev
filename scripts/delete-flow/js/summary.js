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
	return JSON.parse(fs.readFileSync(filePath, 'utf8'));
};

/**
 * Builds the table data for deleted flow versions.
 * @param {object} deletionReport
 * @returns {Array<Array<{data: string, header?: boolean}>>}
 */
export const buildDeletionTableData = (deletionReport) => {
	const detail = JSON.parse(deletionReport?.detail || '{}');
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
	const detail = JSON.parse(deletionReport?.detail || '{}');
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
	
	const deletionReport = readDeletionReport(filePath);
	const summaryInfo = extractSummaryInfo(deletionReport);
	const deletionTableData = buildDeletionTableData(deletionReport);
	
	await writeDeletionSummary(deletionTableData, deletionReport, summaryInfo);
};

main().catch((err) => {
	core.setFailed(`Action failed with error: ${err}`);
});
