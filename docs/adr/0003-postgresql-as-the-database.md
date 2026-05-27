# ADR-0003: Use PostgreSQL as the Primary Database

## Status

Accepted

## Context

The application needs a primary datastore for its core domain: a Workspace
contains Lists, a List contains Tasks, and Members belong to a Workspace and may
be assigned to Tasks. These are strongly relational entities with clear
foreign-key relationships and integrity rules (a Task belongs to exactly one
List; a List belongs to exactly one Workspace). Editing is collaborative, so
concurrent writes to shared Lists and Tasks must not corrupt state.

PostgreSQL has been the working assumption since project setup — it is already
provisioned for local development in `docker-compose.postgres.yml` (PostgreSQL 17) — but the choice has never been recorded as a decision. This ADR captures
it before data-access code (ADR-0004) is written against it.

The launch scope is modest: assumption A2 holds that one Member belongs to one
Workspace (no cross-workspace multi-tenancy yet), and assumption A3 rules out
sub-tasks and dependencies for now. The data model is therefore small and
relational, with room to grow.

## Decision Drivers

- **Relational integrity** — Workspace → List → Task and Member assignments need
  enforced foreign keys and constraints
- **Transactional correctness** — collaborative edits require ACID guarantees so
  concurrent writes stay consistent
- **Operational simplicity** — a small team should not run more datastores than
  necessary
- **Ecosystem and hosting fit** — must pair well with Next.js on Vercel and with
  TypeScript data-access tooling (ADR-0004)
- **Room to grow** — should absorb future needs (search, flexible attributes,
  multi-workspace) without a rewrite

## Considered Options

### Option 1: PostgreSQL

- **Pros**: full ACID compliance; rich relational features and constraints;
  JSONB as an escape hatch for flexible attributes; built-in full-text search;
  excellent TypeScript ORM support (Prisma, Drizzle); first-class managed
  offerings (Vercel Postgres, Neon, Supabase, RDS); already used locally
- **Cons**: requires a managed/hosted instance in production (not embedded);
  vertical-scaling limits eventually require read replicas

### Option 2: MySQL / MariaDB

- **Pros**: mature, widely hosted, simple replication, familiar to many
- **Cons**: weaker JSON ergonomics than JSONB; full-text search less capable;
  no clear advantage over PostgreSQL for this workload

### Option 3: SQLite

- **Pros**: zero-ops, embedded, trivial local development
- **Cons**: weak story for concurrent multi-user writes — the opposite of a
  collaborative app's needs; awkward to operate as a shared production database
  on serverless Vercel

### Option 4: A NoSQL document store (e.g. MongoDB)

- **Pros**: flexible schema; easy horizontal scaling
- **Cons**: the domain is inherently relational (Workspaces own Lists own
  Tasks); enforcing cross-document integrity and transactions adds complexity
  rather than removing it; no schema discipline by default

## Decision

We will use **PostgreSQL 17** as the primary relational datastore.

## Rationale

The domain is relational and integrity-sensitive, which is precisely
PostgreSQL's strength: foreign keys, constraints, and ACID transactions keep
collaborative edits consistent without application-level gymnastics. PostgreSQL
also hedges against future requirements — JSONB for flexible Task attributes,
full-text search for finding Tasks across Lists, and straightforward modelling
of multi-workspace membership should assumption A2 be relaxed — so we are
unlikely to outgrow it. SQLite cannot serve concurrent multi-user writes well,
and a document store fights the relational shape of the data. PostgreSQL is also
already provisioned locally and has the best managed-hosting and TypeScript-ORM
fit for the Next.js-on-Vercel target from ADR-0001, which keeps operational and
data-access decisions (ADR-0004) simple.

## Consequences

### Positive

- Enforced relational integrity and ACID transactions for collaborative edits
- One datastore covers transactions, JSONB flexibility, and full-text search
- Strong managed-hosting options that fit serverless Vercel deployment
- Mature TypeScript ORM ecosystem feeds directly into ADR-0004

### Negative

- A production instance must be provisioned and operated (connection limits
  matter on serverless platforms)
- Horizontal write scaling is non-trivial; heavy growth would need replicas or
  partitioning later

### Risks and mitigations

| Risk                                                 | Mitigation                                                                                                |
| ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Serverless functions exhausting Postgres connections | Use a pooled/serverless driver or a managed pooler (e.g. Vercel Postgres / Neon pooling, PgBouncer)       |
| Schema rigidity slowing early iteration              | Use JSONB for genuinely fluid attributes; evolve the relational schema via reviewed migrations (ADR-0004) |
| Local/production version drift                       | Pin the major version (17) in `docker-compose.postgres.yml` and in the managed instance                   |

## Related Decisions

- ADR-0004: Data Access with an ORM and Migrations — defines how the application
  reads from and migrates this database
- ADR-0002: Expose a REST/JSON API via Route Handlers — the API layer reads and
  writes this database through the data-access layer
