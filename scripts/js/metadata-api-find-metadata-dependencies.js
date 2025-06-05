import fs from "fs";
import * as core from "@actions/core";

const readDependencies = (filePath) => {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
};

const buildDependencyTableData = (dependencies) => {
  const records = dependencies.result.records || [];
  const tableHeader = [
    { data: "Source Name", header: true },
    { data: "Source Type", header: true },
    { data: "Target Name", header: true },
    { data: "Target Type", header: true }
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

const writeDependencySummary = async (dependencyTableData, dependencies) => {
  const DEPENDENCY_REPORT_HEADING = "Metadata Dependency Report";
  const TOTAL_DEPENDENCIES_LABEL = `Total Dependencies: ${dependencies.result.totalSize}`;

  await core.summary
    .addHeading(DEPENDENCY_REPORT_HEADING)
    .addRaw(TOTAL_DEPENDENCIES_LABEL)
    .addBreak()
    .addTable(dependencyTableData)
    .write();
};

const main = async () => {
  const filePath = process.argv[2];
  const dependencies = readDependencies(filePath);
  const dependencyTableData = buildDependencyTableData(dependencies);
  await writeDependencySummary(dependencyTableData, dependencies);
};

main().catch((err) => {
  core.setFailed(`Action failed with error: ${err}`);
});