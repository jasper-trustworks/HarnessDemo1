# ADR-0005: Authentication and Workspace-Scoped Authorization

## Status

Proposed

## Context

The application is primarily authenticated (ADR-0001): a Member signs in and
then views and edits the Lists and Tasks of their Workspace. Two questions need
answers before any protected feature ships:

1. **Authentication** — how Members prove who they are and how sessions are
   maintained across requests.
2. **Authorization** — how the system guarantees a Member can only read and
   write data in a Workspace they belong to.

Authorization is the higher-stakes half. Because the API is an explicit
REST/JSON surface (ADR-0002), every Route Handler is independently reachable, so
access control cannot live only in the UI — it must be enforced server-side on
every request and again in the data-access layer (ADR-0004).

Assumption A2 (one Member belongs to one Workspace, no cross-workspace
multi-tenancy at launch) keeps the model simple now, but the enforcement point
should be designed so that relaxing A2 later is additive rather than a rewrite.

## Decision Drivers

* **Server-side enforcement** — authorization must hold at the API boundary, not
  in the client, since Route Handlers are directly callable
* **Workspace scoping** — every data access must be constrained to the caller's
  Workspace
* **Secure-by-default sessions** — authenticated responses must not be cached or
  leak across users (ties to ADR-0001's `cache: 'no-store'`)
* **Low ceremony for a small team** — prefer a maintained library over bespoke
  crypto and session handling
* **Forward-compatibility** — the design should extend to multiple Workspaces
  per Member without reworking every endpoint

## Considered Options

### Option 1: Auth.js (NextAuth) with database-backed sessions

- **Pros**: built for Next.js App Router; supports OAuth and email/credential
  flows; handles session cookies, CSRF, and rotation; sessions persist in our
  PostgreSQL (ADR-0003); large community
- **Cons**: opinionated abstractions; some configuration to align callbacks with
  our Workspace model

### Option 2: Lucia (or a hand-rolled session library)

- **Pros**: lightweight, explicit, framework-agnostic; full control over the
  session table and cookie handling
- **Cons**: more wiring and security surface to own; fewer turnkey providers;
  more for a small team to get right

### Option 3: Roll our own sessions from scratch

- **Pros**: complete control; no dependency
- **Cons**: re-implements well-solved, security-critical code (hashing, cookie
  flags, CSRF, rotation); high risk; not justified at this scale

### Option 4: A hosted identity provider (Clerk, Auth0)

- **Pros**: fastest to integrate; offloads auth UI, MFA, and compliance
- **Cons**: external dependency and cost; identity data lives off-platform;
  more than the launch scope requires

## Decision

We will use **Auth.js (NextAuth) with database-backed sessions stored in
PostgreSQL**, and enforce **Workspace-scoped authorization server-side** — in
every Route Handler and again in the data-access layer. Every persistence query
is filtered by the authenticated Member's `workspaceId`; no query trusts a
client-supplied workspace identifier.

## Rationale

Auth.js fits the Next.js App Router and the Vercel target from ADR-0001 without
asking us to write security-critical session code ourselves, and its
database-session option reuses the PostgreSQL instance we already chose
(ADR-0003). Lucia and a hand-rolled approach give more control than a small team
needs and enlarge the security surface we must own; a hosted IdP solves more
than launch requires and moves identity data off-platform.

The load-bearing choice is *where* authorization runs. Because ADR-0002 exposes
directly-callable endpoints, we enforce access control on the server every time:
a Route Handler resolves the session, derives the Member's `workspaceId`, and the
data-access layer scopes every read and write to it. Designing the check around a
`workspaceId` derived from membership (rather than hard-coding "one workspace per
user") means relaxing assumption A2 later becomes a membership lookup, not an
endpoint-by-endpoint rewrite. Authenticated responses set `cache: 'no-store'`
(ADR-0001) so one Member's data is never served to another.

## Consequences

### Positive

- Session security (cookies, CSRF, rotation) handled by a maintained library
- Authorization enforced where it cannot be bypassed — the server, on every call
- Workspace scoping centralised in the data-access layer, reducing per-endpoint
  mistakes
- Sessions reuse the existing PostgreSQL instance — no new datastore

### Negative

- Auth.js configuration and callbacks must be aligned with the Workspace model
- Server-side authorization adds a check to every protected Route Handler and
  query
- Database-backed sessions add read load on PostgreSQL (modest at launch)

### Risks and mitigations

| Risk | Mitigation |
|------|-----------|
| A Member accessing another Workspace's data | Scope every query by the session-derived `workspaceId` in the data-access layer; never trust a client-supplied workspace id; cover with authorization tests |
| Authenticated responses cached or shared across users | Set `cache: 'no-store'` on authenticated routes per ADR-0001; mark session cookies `HttpOnly`, `Secure`, `SameSite` |
| Hard-coding A2 (one workspace per user) into endpoints | Derive `workspaceId` from membership so multi-workspace support is an additive change |
| Session-table load as usage grows | Index the session table; revisit JWT or a session cache if read load becomes significant |

## Related Decisions

- ADR-0002: Expose a REST/JSON API via Route Handlers — authorization is enforced
  at this API boundary
- ADR-0004: Data Access with an ORM and Migrations — Workspace scoping is applied
  in the data-access layer
- ADR-0003: Use PostgreSQL as the Primary Database — stores Members and
  database-backed sessions
- ADR-0001: Adopt Next.js as the Frontend Framework — authenticated routes follow
  its `cache: 'no-store'` constraint
