# Collaborative Todo Lists

A customer-facing application that lets users create and share lists and tasks within a
shared workspace. **Current state: scaffold in place — Next.js app and database layer exist;
feature implementation starts from here.**

Stack: **TypeScript · Next.js 15 (App Router, ADR-0001) · PostgreSQL 17 (ADR-0003) · Drizzle ORM (ADR-0004) · Vitest**.

Two sources of truth, split by topic:
- **Product** scope, domain model, assumptions, and feature status → `.spec-lite/project.md`.
- **Technical / architectural** decisions → ADRs in `docs/adr/` (see below).

## Domain vocabulary

Use these terms consistently in code, tests, and docs (defined in `.spec-lite/project.md`):

| Term | Meaning |
|------|---------|
| **Workspace** | Top-level container scoped to a team/org; members share access |
| **List** | Named collection of tasks within a workspace (e.g. "Shopping") |
| **Task** | A to-do item: title, status, optional due date and assignee |
| **Member** | A user belonging to a workspace who can view/edit its lists and tasks |

Open assumptions (still unvalidated): real-time collaboration approach (A1, high risk),
single-workspace-per-user at launch (A2), no sub-tasks/dependencies at launch (A3).

## Architecture decisions

**ADRs in `docs/adr/` are the source of truth for technical and architectural decisions.**
They are authored with the **`architecture-decision-records` skill** (`docs/adr/README.md` is
the index). Accepted ADRs are **immutable** — to change a decision, write a new ADR that
supersedes the old one; never edit an accepted one in place.

Other documents — including `.spec-lite/project.md` — **reference** ADRs rather than restating
their content. Do not duplicate a decision's rationale or constraints outside its ADR; link to
the ADR instead. If any document ever conflicts with an accepted ADR, the ADR wins.

Constraints are documented co-located with the code they govern:
- **App layer** (Next.js, routing, components) → [`src/app/CLAUDE.md`](src/app/CLAUDE.md)
- **Database layer** (PostgreSQL, Drizzle, migrations) → [`src/db/CLAUDE.md`](src/db/CLAUDE.md)

(Note: a leftover `.architecture/` directory exists from an abandoned experiment — ignore it.
ADRs live only in `docs/adr/`.)

## Repository map

| Path | What it is |
|------|-----------|
| `src/app/` | Next.js App Router — pages, layouts, Route Handlers — see [`src/app/README.md`](src/app/README.md) |
| `src/db/` | Database layer: schema, client, migrations — see [`src/db/README.md`](src/db/README.md) |
| `src/drizzle.config.ts` | drizzle-kit config (schema path, migrations dir, dialect) |
| `.env.local.example` | Template for local env vars (copy to `.env.local`, gitignored) |
| `.spec-lite/` | Product definition, domain model, assumptions, feature tracking |
| `docs/adr/` | Architecture Decision Records (+ index and template) |
| `docs/architecture/` | C4 overview (System Context + Container diagrams) |
| `agr.toml` / `agr.lock` | Declared agent skills and their pinned versions |
| `.claude/` | Claude Code project settings, enabled plugins, synced skills |
| `.devcontainer/` | Dev environment: Dockerfile, devcontainer.json, setup scripts |
| `docker-compose.postgres.yml` | PostgreSQL 17 service for local development |

## Toolchain & when to use it

**Agent skills (`agr`)** — 19 skills are declared in `agr.toml`, pinned in `agr.lock`, and
synced into `.claude/skills/` automatically on session start. The relevant ones by area:
- Frontend/React: `react-best-practices`, `react-component-performance`, `composition-patterns`, `web-design-guidelines`
- Backend: `backend-dev-guidelines`, `error-handling-patterns`
- API: `api-design-principles`, `api-security-best-practices`
- Data: `postgresql-optimization`, `database-migrations-sql-migrations`
- Architecture/DDD: `domain-driven-design`, `ddd-tactical-patterns`, `architecture-patterns`, `architecture-decision-records`, `c4-architecture`
- Quality: `clean-code`, `e2e-testing-patterns`, `auth-implementation-patterns`, `accessibility-compliance-accessibility-audit`

**Plugins / slash-workflows** (enabled in `.claude/settings.json`): `spec-lite`,
`tw-code-review`, `socratic-ideation`, `gitnexus`, `claude-md-management`, `typescript-lsp`,
`frontend-design`, `commit-commands`, and more.

**Reach for:**
- **A new feature** → `spec-lite` (`/spec-lite:spec` → `/spec-lite:tasks` → `/spec-lite:implement`).
- **A technical/architectural choice** → the `architecture-decision-records` skill; record the outcome as an ADR in `docs/adr/`.
- **Before merging** → `tw-code-review`.
- **Navigating the codebase** → `gitnexus` (knowledge graph; re-index with `npx gitnexus analyze` after big changes).

## Operating rules (environment)

Full detail lives in `README.md`; the rules that affect how you run commands:

- **Permission mode is `auto`** with the native **sandbox** enabled — sandboxed Bash runs
  without prompts. Configure trusted infra in `.claude/settings.local.json` (NOT
  `settings.json` — the classifier ignores `autoMode` from shared project settings).
- **Egress firewall is whitelist-only.** If a tool fails with a network error, the domain is
  likely blocked — add it to `EXTRA_FIREWALL_DOMAINS` in `devcontainer.json` → `containerEnv`.
- **Environment persistence** via `/etc/sandbox-persistent.sh` (`CLAUDE_ENV_FILE`). Append
  with `echo "export VAR=value" >> /etc/sandbox-persistent.sh`. **CRITICAL: never add shell
  completion scripts to this file — they break the bash tool.** Only core init scripts.
- **Git identity** comes from `.devcontainer/.env.local` (gitignored). If a developer's
  identity is unset, point them there first; in-container `git config --global` does not
  survive a rebuild.
- **PostgreSQL:** `docker compose -f docker-compose.postgres.yml up -d`.
  Connection string: `postgresql://postgres:postgres@localhost:5432/app_db` (set as `DATABASE_URL`).
  Apply migrations before running the app: `npm run db:migrate`.
- **`NODE_ENV` quirk:** the devcontainer sets `NODE_ENV=development` globally. Pass
  `NODE_ENV=production npm run build` explicitly for production builds.

## Coding conventions

- TypeScript throughout; Next.js App Router (Server Components by default — see ADR-0001).
- Tests in **Vitest** (`npm test` / `npm run test:watch`).
- Honor the installed skills — especially `clean-code`, `react-best-practices`, and
  `backend-dev-guidelines` — rather than reinventing patterns.

Area-specific conventions live co-located with each directory:
- `src/app/CLAUDE.md` — Next.js component, routing, and Route Handler patterns
- `src/db/CLAUDE.md` — schema, migration workflow, and repository patterns

See `README.md` for full environment setup, Claude Code authentication, and troubleshooting.
