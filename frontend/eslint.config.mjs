import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  // Override default ignores of eslint-config-next.
  globalIgnores([
    // Default ignores of eslint-config-next:
    ".next/**",
    "out/**",
    "build/**",
    "next-env.d.ts",
  ]),
  // This legacy client code still has a gradual typing backlog. Keep it visible
  // without letting it mask real build and React correctness failures.
  {
    rules: {
      "@typescript-eslint/no-explicit-any": "warn",
    },
  },
]);

export default eslintConfig;
