import { defineConfig } from "drizzle-kit";

export default defineConfig({
  // NOTE: schema/out are resolved relative to the cwd (repo root, where npm runs),
  // NOT relative to this file's location in src/.
  schema: "./src/db/schema.ts",
  out: "./src/db/migrations",
  dialect: "postgresql",
  dbCredentials: {
    url: process.env.DATABASE_URL!,
  },
});
