# ADR-0002: Expose a REST/JSON API via Route Handlers

## Status

Proposed

## Context

ADR-0001 adopted Next.js with the App Router, whose default data and mutation
path is React Server Components plus Server Actions. The interactive surface of
this product, however, is client-driven: members edit Lists and Tasks in a
shared Workspace, expect optimistic updates, and the real-time-collaboration
approach is still unresolved (assumption A1, high risk). Client Components need
a stable way to read and mutate data *after* hydration, without a full
server-rendered round-trip per interaction.

We need an explicit, named contract between that client surface — the "SPA" the
product is described as — and the backend. We also want that boundary to be
testable on its own and, potentially, consumable by non-browser clients later.

The decision is proactive — made before application code exists — to establish
a contract convention before routes proliferate and the cost of changing the
boundary becomes high.

## Decision Drivers

* **Explicit client-server contract** — Client Components need a stable,
  documented way to read and mutate Workspaces, Lists, and Tasks after hydration
* **Testability** — an HTTP boundary can be exercised independently of React
  rendering
* **Compatibility with ADR-0001** — must stay inside the Next.js App Router, not
  introduce a separate backend service
* **Future clients and real-time** — keep the door open for non-web clients and
  for whatever real-time approach resolves assumption A1
* **Cache safety** — authenticated data must never be served stale

## Considered Options

### Option 1: Server Actions only (the ADR-0001 default)

- **Pros**: least boilerplate; co-located with components; progressive
  enhancement for forms; type-safe end to end within the framework
- **Cons**: no explicit or versioned contract; awkward for read-heavy client
  interactions and polling; not consumable by non-Next.js clients; harder to
  test as a standalone boundary; RPC-shaped rather than resource-shaped

### Option 2: REST/JSON API via Route Handlers

- **Pros**: explicit, resource-oriented contract under `app/api/**/route.ts`;
  standard HTTP semantics (status codes, caching, idempotency); testable without
  rendering React; consumable by any client; matches the "SPA + API" mental
  model; stays inside Next.js, so it honours ADR-0001
- **Cons**: more boilerplate than Server Actions; the team must define and police
  conventions (error shape, versioning, pagination); risks two mutation paths if
  Server Actions are also used

### Option 3: GraphQL

- **Pros**: flexible querying from a single endpoint; strong typing; avoids
  over- and under-fetching
- **Cons**: heavy for a small, CRUD-shaped domain; caching and versioning are
  more complex; extra server libraries and a learning curve; overkill at launch

### Option 4: tRPC

- **Pros**: end-to-end TypeScript types with no codegen; very low boilerplate;
  excellent DX inside a TypeScript codebase
- **Cons**: couples the client to server types rather than a language-neutral
  contract; not REST; unfriendly to non-TypeScript or non-web clients; another
  abstraction to learn

## Decision

We will expose the backend as an explicit **REST/JSON API implemented with
Next.js Route Handlers** (`app/api/**/route.ts`), consumed by Client Components
via `fetch`. Server Actions remain available for simple, form-driven mutations
(progressive-enhancement forms), but the **canonical contract for interactive
client behaviour is the REST/JSON API**.

## Rationale

The product's interactive, client-driven editing needs a contract that survives
hydration and can be tested and evolved on its own — exactly what Server Actions
alone do not give us. GraphQL and tRPC are heavier or more coupled than a
todo-list domain (Workspaces, Lists, Tasks) warrants: GraphQL's flexibility is
unneeded for largely CRUD operations, and tRPC's type-coupling works against the
language-neutral boundary we want for future clients and the open real-time
question (A1).

REST over Route Handlers gives the explicit "API" the product calls for while
staying entirely inside the Next.js App Router — no separate service, so
ADR-0001's full-stack-colocation benefit is preserved. We accept the extra
boilerplate. To prevent drift, we set conventions now: resource-oriented paths
(e.g. `/api/workspaces/:id/lists`, `/api/lists/:id/tasks`), JSON request and
response bodies, conventional HTTP status codes, a consistent error envelope
(`{ "error": { "code", "message" } }`), pagination on collection endpoints, and
a versioning approach (path prefix such as `/api/v1`) chosen before the first
external client. Per ADR-0001, authenticated Route Handlers set
`cache: 'no-store'` so member data is never served stale.

## Consequences

### Positive

- An explicit, documented boundary shared by Client Components and any future
  client
- Testable in isolation with HTTP-level tests, independent of React rendering
- Standard HTTP semantics provide caching, status codes, and idempotency
- Stays within Next.js and Vercel — no additional service to deploy, honouring
  ADR-0001

### Negative

- More boilerplate per resource than Server Actions
- Two mutation styles (Route Handlers and Server Actions) can confuse
  contributors unless the split is documented
- A hand-written contract can drift without an enforced schema

### Risks and mitigations

| Risk | Mitigation |
|------|-----------|
| Inconsistent endpoints and error shapes as routes grow | Adopt a shared request/response and error-envelope helper, and document the REST conventions before the first feature ships |
| Stale authenticated data from caching | Default authenticated Route Handlers to `cache: 'no-store'` per ADR-0001; opt into caching explicitly and deliberately |
| Ambiguity over Server Actions vs Route Handlers | Document the rule: Route Handlers for client-consumed reads and mutations; Server Actions only for simple server-rendered forms |
| Contract drift between client and server | Validate payloads at the boundary (e.g. Zod schemas) and consider generating an OpenAPI spec or typed client once endpoints stabilise |

## Related Decisions

- ADR-0001: Adopt Next.js as the Frontend Framework — this ADR refines ADR-0001
  by defining an explicit API surface within the App Router rather than relying
  solely on Server Actions
- ADR-0005: Authentication and Workspace Authorization — authorization is
  enforced at this API boundary
- ADR-0004: Data Access with an ORM and Migrations — Route Handlers call the
  data-access layer rather than reaching the database directly
