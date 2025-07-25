import { jestConfig } from '@salesforce/sfdx-lwc-jest/config.js';

export default {
    ...jestConfig,
    modulePathIgnorePatterns: ['<rootDir>/.localdevserver']
};