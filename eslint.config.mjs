import { dirname } from "path";
import { fileURLToPath } from "url";
import { FlatCompat } from "@eslint/eslintrc";
import sonarjs from "eslint-plugin-sonarjs";
import prettierConfig from "eslint-config-prettier";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const compat = new FlatCompat({
  baseDirectory: __dirname,
});

const eslintConfig = [
  ...compat.extends("next/core-web-vitals", "next/typescript"),
  {
    ignores: [
      "node_modules/**",
      ".next/**",
      ".devcontainer/**",
      "src/coverage/**",
      "out/**",
      "build/**",
      "next-env.d.ts",
      // git worktrees (checked-out branches inside the repo) — linted on their
      // own branches, not alongside the main tree
      ".worktrees/**",
      ".claude/worktrees/**",
    ],
  },
  sonarjs.configs.recommended,
  prettierConfig,
];

export default eslintConfig;
