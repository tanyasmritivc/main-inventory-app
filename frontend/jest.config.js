/** @type {import('jest').Config} */
const config = {
  testEnvironment: 'node',
  transform: {
    '^.+\\.tsx?$': ['ts-jest', { tsconfig: './tsconfig.jest.json' }],
  },
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1',
    '\\.module\\.css$': '<rootDir>/src/__tests__/style-mock.js',
  },
  testMatch: ['<rootDir>/src/__tests__/**/*.test.ts', '<rootDir>/src/__tests__/**/*.test.tsx'],
};

module.exports = config;
