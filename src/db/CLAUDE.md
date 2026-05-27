# Database Layer (`src/db/`)

Agent instructions for this directory. See `README.md` for the developer overview.

## ADR constraints in force

**ADR-0003 (PostgreSQL):**
- All schema changes must go through a reviewed Drizzle migration — no ad-hoc DDL.
- Use a serverless-safe connection strategy (`max: 1` or a managed pooler) — see `client.ts`.

**ADR-0004 (Drizzle ORM):**
- Route Handlers call repository functions from this directory; they never import `db` and write raw Drizzle queries inline.
- `schema.ts` is the single source of truth for the data model.

## Migration workflow

1. Edit table/enum definitions in `schema.ts`
2. `npm run db:generate` — Drizzle diffs the schema and writes a SQL migration to `migrations/`
3. Review the generated SQL before applying
4. `npm run db:migrate` — applies to the local database
5. Commit `schema.ts` and the new migration file together

## Repository pattern

Add repository functions in `src/db/` (one file per domain entity, e.g. `users.ts`, `lists.ts`). Route Handlers import these functions — never import `db` directly into a route handler.

## Schema overview

| Table | Key fields | Notes |
|-------|-----------|-------|
| `users` | `id`, `email` (unique), `name` | Global user registry |
| `workspaces` | `id`, `name` | Top-level container |
| `members` | `userId`, `workspaceId` | Join table; no `updatedAt` — immutable after creation |
| `lists` | `workspaceId`, `name` | Scoped to workspace; cascade deletes with workspace |
| `tasks` | `listId`, `title`, `status`, `dueDate?`, `assigneeId?` | `assigneeId` nullable (unassigned is valid); `listId` NOT NULL |

Enum: `task_status` — `"todo" | "in_progress" | "done"`

All IDs are UUIDs with `defaultRandom()`. All timestamps use `defaultNow()`.

## Relevant skills

- `database-migrations-sql-migrations` — migration authoring and review
- `postgresql-optimization` — query tuning and indexing strategies
- `backend-dev-guidelines` — repository and service layer patterns
