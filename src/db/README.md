# src/db — Database Layer

Drizzle ORM over PostgreSQL 17. This directory is the data-access layer for the entire app.

## Files

| File | Purpose |
|------|---------|
| `schema.ts` | Single source of truth for all table and enum definitions |
| `client.ts` | Drizzle client singleton — `import { db } from '@/db/client'` |
| `migrations/` | Generated SQL migrations — checked in, applied on deploy |
| `../drizzle.config.ts` | drizzle-kit config pointing at this directory |

## Local setup

```bash
# 1. Start PostgreSQL
docker compose -f docker-compose.postgres.yml up -d

# 2. Ensure DATABASE_URL is set (copy .env.local.example → .env.local)
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/app_db

# 3. Apply migrations
npm run db:migrate

# 4. (Optional) Open Drizzle Studio
npm run db:studio
```

## Changing the schema

```bash
# Edit src/db/schema.ts, then:
npm run db:generate   # creates a new migration in src/db/migrations/
# review the generated SQL, then:
npm run db:migrate    # applies to local DB
```

Always commit `schema.ts` and the new migration file together.

## Schema at a glance

| Table | Purpose |
|-------|---------|
| `users` | Global user registry (email unique) |
| `workspaces` | Top-level containers |
| `members` | Join table linking users ↔ workspaces |
| `lists` | Named task collections scoped to a workspace |
| `tasks` | To-do items: title, status, optional due date and assignee |

See `schema.ts` for the authoritative column definitions and `CLAUDE.md` for agent conventions.
