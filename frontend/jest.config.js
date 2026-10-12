/** @type {import('jest').Config} */
const config = {
  testEnvironment: 'node',
  transform: {
    '^.+\\.[tj]sx?$': ['ts-jest', { tsconfig: './tsconfig.jest.json' }],
  },
  transformIgnorePatterns: ['node_modules/(?!(react-markdown|remark-.*|rehype-.*|unified|vfile.*|unist-.*|hast-.*|mdast-.*|micromark.*|decode-named-character-reference|character-entities.*|character-reference-invalid|parse-entities|stringify-entities|is-alphanumerical|is-alphabetical|is-decimal|is-hexadecimal|html-url-attributes|property-information|style-to-js|style-to-object|inline-style-parser|comma-separated-tokens|space-separated-tokens|trim-lines|trough|bail|devlop|ccount|escape-string-regexp|is-plain-obj|markdown-table|zwitch|longest-streak|estree-util-.*|@ungap/structured-clone)/)'],
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1',
    '\\.css$': '<rootDir>/src/__tests__/style-mock.js',
  },
  testMatch: ['<rootDir>/src/__tests__/**/*.test.ts', '<rootDir>/src/__tests__/**/*.test.tsx'],
};

module.exports = config;
