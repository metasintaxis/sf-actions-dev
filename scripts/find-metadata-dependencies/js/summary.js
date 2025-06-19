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

export const readDependencies = (filePath) => {
	return JSON.parse(fs.readFileSync(filePath, 'utf8'));
};

export const buildDependencyTableData = (dependencies) => {
	// Updated to support new JSON structure
	const records = dependencies?.detail?.result?.records || [];
	const tableHeader = [
		{ data: 'Source Name', header: true },
		{ data: 'Source Type', header: true },
		{ data: 'Target Name', header: true },
		{ data: 'Target Type', header: true }
	];
	const tableData = [tableHeader];

	for (const record of records) {
		tableData.push([
			{ data: record.RefMetadataComponentName },
			{ data: record.RefMetadataComponentType },
			{ data: record.MetadataComponentName },
			{ data: record.MetadataComponentType }
		]);
	}
	return tableData;
};

export const writeDependencySummary = async (
	dependencyTableData,
	dependencies
) => {
	const DEPENDENCY_REPORT_HEADING = 'Metadata Dependency Report';
	const TOTAL_DEPENDENCIES_LABEL = `Total Dependencies: ${dependencies?.detail?.result?.totalSize ?? 0}`;

	await core.summary
		.addHeading(DEPENDENCY_REPORT_HEADING)
		.addRaw(TOTAL_DEPENDENCIES_LABEL)
		.addBreak()
		.addTable(dependencyTableData)
		.write();
};

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
