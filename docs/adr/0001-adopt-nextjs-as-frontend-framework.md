# ADR-0001: Adopt Next.js as the Frontend Framework

## Status

Accepted

## Context

We are building a primarily authenticated web application (dashboards, app
shell, logged-in flows) and need to choose a frontend framework. SEO is not
a primary concern; most pages sit behind authentication.

The decision is proactive — made before significant frontend code exists —
to establish a direction before the cost of switching becomes high.

The application will be deployed to Vercel.

## Decision Drivers

- **Full-stack colocation** — server-side data fetching and backend logic
  should live in the same repository as the UI, without requiring a separate
  API service for every new route
- **Avoid client-side data waterfalls** — authenticated apps with nested data
  dependencies benefit from server-side composition (React Server Components)
- **File-based routing convention** — reduces boilerplate and enforces a
  consistent structure as the codebase grows
- **Deployment fit** — Vercel provides first-class Next.js support: zero-config
  deploys, edge functions, and native Server Action infrastructure

## Considered Options

### Option 1: Next.js (App Router)

- **Pros**: React Server Components reduce client bundle size and enable
  server-side data fetching without separate API calls; Server Actions replace
  many REST endpoints for mutations; file-based routing; API routes for any
  remaining backend needs; first-class Vercel support; large ecosystem
  (shadcn/ui, next-auth, etc.)
- **Cons**: App Router is still maturing (caching model is complex and has
  changed across versions); adds a Node.js server requirement compared to a
  pure SPA; framework abstractions can obscure what is running where

### Option 2: Vite + React SPA

- **Pros**: Simpler mental model (everything is client-side); very fast local
  dev builds; no server to manage; pure static output deploys anywhere
- **Cons**: Requires a separate backend for any server-side logic (API,
  auth callbacks, data fetching); client-side data fetching creates waterfalls
  on page load; no built-in routing — needs React Router or TanStack Router
  configuration; larger initial bundle for data-heavy dashboards

## Decision

We will use **Next.js 15 with the App Router** as our frontend framework.

## Rationale

For an authenticated application with nested data dependencies, the App Router's
React Server Components model directly solves our main concern: avoiding
round-trip waterfalls where the client fetches layout, then data, then more
data. Server Components let us fetch data on the server and stream rendered
HTML to the client.

Server Actions further reduce the need for a separate API layer for mutations,
keeping full-stack logic co-located. This is a meaningful reduction in
cross-repository coordination for a small team.

Vite + React SPA is a good choice for applications where the backend is already
established and client-side rendering is preferred. Here, we are starting
fresh, and a meta-framework that provides routing, server rendering, and API
routes from day one reduces decisions and infrastructure surface.

The Vercel deployment target makes operational overhead of running a Node.js
server negligible compared to self-hosting.

## Consequences

### Positive

- Collocated frontend and backend logic reduces friction for full-stack features
- React Server Components reduce client bundle size and eliminate many
  client-side data-fetching patterns
- Server Actions simplify form handling and mutations without a separate REST
  layer
- File-based routing enforces structure and keeps route discovery obvious
- Vercel deploys with zero additional configuration

### Negative

- App Router caching semantics (request memoization, Data Cache, Full Route
  Cache) are non-trivial; developers need to learn when `cache: 'no-store'`
  or `revalidate` is appropriate
- Harder to run as a pure static site if hosting requirements change
- "Is this Server Component or Client Component?" is a new mental model
  burden that doesn't exist in a pure SPA

### Risks and mitigations

| Risk                                                   | Mitigation                                                                                                                                       |
| ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| Caching behaviour surprises (stale data in production) | Default to `no-store` for authenticated routes; add caching explicitly only when needed                                                          |
| Team unfamiliarity with RSC boundary rules             | Establish a convention: start every new component as a Server Component and add `'use client'` only when required (event handlers, browser APIs) |
| Next.js breaking changes across minor versions         | Pin to a minor version in CI; review changelog before upgrading                                                                                  |

## Related Decisions

- _None yet — link here when auth strategy or API layer ADRs are written_
