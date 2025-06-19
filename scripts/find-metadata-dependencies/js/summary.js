/**
 * @file metadata-api-find-metadata-dependencies.js
 * @brief Summarizes Salesforce metadata dependencies as a GitHub Actions summary table.
 *
 * @description
 *   Reads a JSON file produced by the dependency Bash script, extracts dependency information,
 *   and writes a formatted summary table to the GitHub Actions summary using @actions/core.
 *
 * @usage
 *   node metadata-api-find-metadata-dependencies.js <dependencies-report.json>
 */

import fs from 'fs';
import * as core from '@actions/core';

/**
 * Reads and parses the dependencies JSON file.
 * @param {string} filePath
 * @returns {object}
 */
export const readDependencies = (filePath) => {
	return JSON.parse(fs.readFileSync(filePath, 'utf8'));
};

/**
 * Builds the table data for dependent components.
 * @param {object} dependencies
 * @returns {Array<Array<{data: string, header?: boolean}>>}
 */
export const buildDependencyTableData = (dependencies) => {
	const records = dependencies?.detail?.result?.records || [];
	const tableHeader = [
		{ data: 'Dependent Component Name', header: true },
		{ data: 'Type', header: true },
		{ data: 'Component Id', header: true }
	];
	const tableData = [tableHeader];

	for (const record of records) {
		tableData.push([
			{ data: record.MetadataComponentName },
			{ data: record.MetadataComponentType },
			{ data: record.MetadataComponentId }
		]);
	}
	return tableData;
};

/**
 * Writes the dependency summary to the GitHub Actions summary.
 * @param {Array} dependencyTableData
 * @param {object} dependencies
 */
export const writeDependencySummary = async (
	dependencyTableData,
	dependencies
) => {
	const DEPENDENCY_REPORT_HEADING = 'Metadata Dependency Report';
	const total = dependencies?.detail?.result?.totalSize ?? 0;
	const firstRecord = dependencies?.detail?.result?.records?.[0] || {};
	const sourceName = firstRecord.RefMetadataComponentName || 'Unknown';
	const sourceType = firstRecord.RefMetadataComponentType || 'Unknown';
	const sourceId = firstRecord.RefMetadataComponentId || 'Unknown';

	await core.summary
		.addHeading(DEPENDENCY_REPORT_HEADING)
		.addMarkdown(
			`**Component Analyzed:**\n- Name: \`${sourceName}\`\n- Type: \`${sourceType}\`\n- Id: \`${sourceId}\``
		)
		.addBreak()
		.addRaw(`Total Dependencies: ${total}`)
		.addBreak()
		.addTable(dependencyTableData)
		.write();
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
	const dependencies = readDependencies(filePath);
	const dependencyTableData = buildDependencyTableData(dependencies);
	await writeDependencySummary(dependencyTableData, dependencies);
};

main().catch((err) => {
	core.setFailed(`Action failed with error: ${err}`);
});
