import path from "path";
import postgres from "postgres";
import { drizzle } from "drizzle-orm/postgres-js";
import { migrate } from "drizzle-orm/postgres-js/migrator";

const DB_NAME = "app_db_test";
const ADMIN_URL = "postgresql://postgres:postgres@localhost:5432/postgres"; // NOSONAR — local test credential
const TEST_URL =
  process.env.E2E_DATABASE_URL ??
  `postgresql://postgres:postgres@localhost:5432/${DB_NAME}`; // NOSONAR — local test credential

export default async function globalSetup() {
  if (process.env.CI) {
    // CI: the pipeline bootstrap step provisions and migrates the test database.
    console.log("[e2e globalSetup] CI detected — skipping local DB setup");
    return;
  }

  // Drop and recreate the test database for a clean slate.
  const admin = postgres(ADMIN_URL, { max: 1 });
  await admin`
    SELECT pg_terminate_backend(pid)
    FROM pg_stat_activity
    WHERE datname = ${DB_NAME} AND pid <> pg_backend_pid()
  `;
  await admin.unsafe(`DROP DATABASE IF EXISTS ${DB_NAME}`);
  await admin.unsafe(`CREATE DATABASE ${DB_NAME}`);
  await admin.end();
  console.log(`[e2e globalSetup] Created database ${DB_NAME}`);

  // Apply all Drizzle migrations against the fresh database.
  const sql = postgres(TEST_URL, { max: 1 });
  const db = drizzle(sql);
  await migrate(db, {
    migrationsFolder: path.resolve("./src/db/migrations"),
  });
  console.log("[e2e globalSetup] Migrations applied");

  // Seed minimal fixture data so tests have known rows to assert against.
  await sql`
    INSERT INTO users (id, email, name)
    VALUES (
      'e2e00000-0000-0000-0000-000000000001',
      'e2e@example.com',
      'E2E User'
    )
  `;
  await sql`
    INSERT INTO workspaces (id, name)
    VALUES (
      'e2e00000-0000-0000-0000-000000000002',
      'E2E Workspace'
    )
  `;
  await sql`
    INSERT INTO members (id, user_id, workspace_id)
    VALUES (
      'e2e00000-0000-0000-0000-000000000003',
      'e2e00000-0000-0000-0000-000000000001',
      'e2e00000-0000-0000-0000-000000000002'
    )
  `;
  await sql`
    INSERT INTO lists (id, workspace_id, name)
    VALUES (
      'e2e00000-0000-0000-0000-000000000004',
      'e2e00000-0000-0000-0000-000000000002',
      'E2E List'
    )
  `;
  await sql`
    INSERT INTO tasks (id, list_id, title, status)
    VALUES (
      'e2e00000-0000-0000-0000-000000000005',
      'e2e00000-0000-0000-0000-000000000004',
      'E2E Task',
      'todo'
    )
  `;
  await sql.end();
  console.log("[e2e globalSetup] Seed data loaded");
}
