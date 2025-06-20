/**
 * @file summary.js
 * @brief Summarizes Salesforce metadata dependencies as a GitHub Actions summary table.
 *
 * @description
 *   Reads a JSON file produced by the dependency Bash script, extracts dependency information,
 *   and writes a formatted summary table to the GitHub Actions summary using @actions/core.
 *
 * @usage
 *   node summary.js <dependencies-report.json>
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
			{ data: record.MetadataComponentName || '' },
			{ data: record.MetadataComponentType || '' },
			{ data: record.MetadataComponentId || '' }
		]);
	}
	return tableData;
};

/**
 * Builds a table for the source component.
 * @param {object} record
 * @returns {Array<Array<{data: string, header?: boolean}>>}
 */
export const buildSourceComponentTable = (record) => {
	return [
		[
			{ data: 'Id', header: true },
			{ data: 'Type', header: true },
			{ data: 'Name', header: true }
		],
		[
			{ data: record.RefMetadataComponentId || 'Unknown' },
			{ data: record.RefMetadataComponentType || 'Unknown' },
			{ data: record.RefMetadataComponentName || 'Unknown' }
		]
	];
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
	const SOURCE_COMPONENT_HEADING = 'Source Component';
	const total = dependencies?.detail?.result?.totalSize ?? 0;
	const records = dependencies?.detail?.result?.records || [];
	const firstRecord = records[0] || {};
	const sourceComponentTable = buildSourceComponentTable(firstRecord);

	await core.summary
		.addHeading(DEPENDENCY_REPORT_HEADING)
		.addHeading(SOURCE_COMPONENT_HEADING, 4)
		.addTable(sourceComponentTable)
		.addBreak()
		.addRaw(`<b>Total Dependencies:</b> ${total}`)
		.addBreak();

	if (total > 0) {
		await core.summary.addTable(dependencyTableData);
	} else {
		await core.summary.addRaw('No dependencies found.');
	}

	const warnings = dependencies?.detail?.warnings || [];
	if (warnings.length > 0) {
		await core.summary
			.addBreak()
			.addHeading('Warnings')
			.addList(warnings);
	}

	if (dependencies?.timestamp) {
		await core.summary
			.addBreak()
			.addRaw(
				`<sub>Report generated: ${dependencies.timestamp}</sub>`
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
	const dependencies = readDependencies(filePath);
	const dependencyTableData = buildDependencyTableData(dependencies);
	await writeDependencySummary(dependencyTableData, dependencies);
};

main().catch((err) => {
	core.setFailed(`Action failed with error: ${err}`);
});
