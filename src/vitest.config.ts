import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  plugins: [react()],
  test: {
    environment: "jsdom",
    globals: true,
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
