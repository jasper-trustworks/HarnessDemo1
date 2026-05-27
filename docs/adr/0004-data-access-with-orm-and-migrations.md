# ADR-0004: Data Access with a TypeScript Query Layer and Migrations

## Status

Accepted

## Context

With PostgreSQL chosen (ADR-0003) and a REST/JSON API planned (ADR-0002), we
need to decide how application code reaches the database and how the schema
evolves over time. Route Handlers should not issue ad-hoc SQL from request
handlers; we want a data-access layer that the API calls, type safety from the
database through to the API boundary, and a disciplined way to change the schema
as features land.

This is the **most genuinely open** of the decisions recorded in this batch: the
team has expressed no prior preference, and the three credible options are all
reasonable. This ADR therefore leads with a recommendation but lays out the
alternatives in full so the choice can be confirmed or redirected at review time
rather than settled by default.

The constraints that matter: TypeScript throughout (per the project stack),
Next.js on serverless Vercel (connection-pooling-sensitive, per ADR-0003), a
small relational schema today (assumptions A2/A3) that will grow, and a small
team that benefits from low ceremony.

## Decision Drivers

- **Type safety end to end** — query results should be typed and flow into the
  API contract without hand-maintained types
- **Migration discipline** — schema changes must be versioned, reviewed, and
  applied predictably (forward-only, with a rollback story)
- **Serverless fit** — must work within Postgres connection limits on Vercel
- **Low ceremony for a small team** — minimise boilerplate and conceptual
  overhead
- **SQL transparency** — the team should be able to reason about the SQL that
  runs, especially as data grows

## Considered Options

### Option 1: Drizzle ORM (+ drizzle-kit migrations)

- **Pros**: thin, SQL-first, schema defined in TypeScript with inferred types;
  generated SQL is predictable and close to hand-written; excellent serverless
  and edge support; lightweight migrations via `drizzle-kit`
- **Cons**: younger ecosystem than Prisma; fewer batteries-included features;
  more SQL knowledge expected of contributors

### Option 2: Prisma ORM

- **Pros**: mature, excellent DX; declarative schema with strong codegen and
  autocompletion; robust, well-documented migration workflow (`prisma migrate`);
  large community
- **Cons**: heavier runtime and query engine; historically needs care with
  serverless connection pooling (mitigated by Prisma's pooling/Accelerate or a
  managed pooler); generated client can obscure the emitted SQL

### Option 3: Raw SQL + a query builder, with a standalone migration runner

- **Pros**: maximum control and transparency over SQL; minimal abstraction; e.g.
  `pg` + Kysely for typed queries, plus `node-pg-migrate` or plain SQL files
- **Cons**: more wiring to assemble; types and queries are more manual; the team
  builds conventions an ORM would provide out of the box

## Decision

We will use **Drizzle ORM with `drizzle-kit` migrations** as the data-access
layer, wrapped behind a thin repository module that the Route Handlers call.

> **Open for confirmation at acceptance.** This is a recommendation, not a
> settled default. If the team values Prisma's maturity and DX over Drizzle's
> SQL-first lightness — or wants the full control of raw SQL — say so during
> review and this ADR will be revised before it is accepted.

## Rationale

Drizzle best fits the drivers: it gives end-to-end TypeScript types with a thin,
SQL-first model whose emitted queries stay transparent as the data grows, and it
has strong serverless support that suits the Vercel target (ADR-0003). Its
migrations are lightweight, which keeps ceremony low for a small team. Prisma is
the strong runner-up — its DX and migration tooling are excellent — but its
heavier runtime and historical serverless-pooling caveats are friction we would
rather avoid at this size; it remains the obvious fallback if the team prefers
its ergonomics. Raw SQL maximises control but asks us to hand-build the typing
and migration conventions that Drizzle already provides.

Regardless of the tool chosen, the structural decisions hold: Route Handlers
call a repository/data-access module (never raw SQL inline), schema changes ship
as **forward-only, reviewed migrations** checked into the repo, and a connection
strategy compatible with serverless Postgres is used (see ADR-0003).

## Consequences

### Positive

- Typed queries flow from the database into the ADR-0002 API contract
- A single repository layer isolates persistence from Route Handlers, keeping
  the API testable
- Versioned migrations make schema evolution reviewable and reproducible across
  environments

### Negative

- A schema-definition and migration tool is a dependency to learn and keep
  current
- Drizzle's younger ecosystem means fewer ready-made recipes than Prisma
- If the recommendation is overturned at acceptance, early scaffolding may need
  reworking

### Risks and mitigations

| Risk                                               | Mitigation                                                                                                                               |
| -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Connection exhaustion on serverless Postgres       | Use a serverless/pooled driver or managed pooler as decided in ADR-0003                                                                  |
| Migrations that are hard to roll back              | Keep migrations small and forward-only; pair destructive changes with an expand/contract sequence; rehearse on a non-production database |
| Tool choice churns after code exists               | Confine database access to the repository layer so the ORM is swappable behind a stable interface                                        |
| Drift between TypeScript types and the live schema | Generate types from the schema/migrations as part of the build; fail CI on drift                                                         |

## Related Decisions

- ADR-0003: Use PostgreSQL as the Primary Database — this layer reads from and
  migrates that database
- ADR-0002: Expose a REST/JSON API via Route Handlers — Route Handlers consume
  this data-access layer rather than the database directly
