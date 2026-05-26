import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import * as schema from "./schema";

const connectionString = process.env.DATABASE_URL;
if (!connectionString) {
  throw new Error("DATABASE_URL is not set");
}

// Use max:1 on serverless (each function invocation gets its own connection).
// For long-running server processes, raise this or use a pooler (see ADR-0003).
const sql = postgres(connectionString, { max: 1 });

export const db = drizzle(sql, { schema });
