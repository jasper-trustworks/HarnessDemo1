import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": __dirname,
    },
  },
  test: {
    environment: "jsdom",
    globals: true,
    // Unit tests are co-located in src and named *.test.ts(x) (ADR-0007). Scoping
    // include here keeps vitest from globbing the Playwright e2e/*.spec.ts files
    // (which crash under vitest). Integration tests use a separate config.
    include: ["src/**/*.test.{ts,tsx}"],
    exclude: ["src/**/*.integration.test.{ts,tsx}"],
    // Don't fail the run (or the pre-push gate / CI) before any unit tests exist.
    passWithNoTests: true,
    coverage: {
      provider: "v8",
      reporter: ["lcov", "text"],
      reportsDirectory: resolve(__dirname, "coverage"),
      exclude: [
        "node_modules/**",
        "db/migrations/**",
        "**/*.config.*",
        "**/*.d.ts",
      ],
    },
  },
});
