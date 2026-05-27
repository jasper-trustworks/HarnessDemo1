# ADR-0007: Testing Strategy — Unit, Integration, and End-to-End

## Status

Accepted

## Context

The project has Vitest installed with a single config (`src/vitest.config.ts`) targeting jsdom
for React component tests. No integration or E2E tests exist yet. As feature implementation
starts from the current scaffold, we need a defined testing strategy that:

- Provides fast feedback during development
- Validates the database layer (Drizzle repositories) against a real PostgreSQL instance
- Exercises complete user flows through the Next.js app
- Integrates cleanly into CI

The strategy is adapted from the testing approach used in the DigitalPostSandbox project (same
team, same core stack: Vitest, Playwright, PostgreSQL 17), which has validated this pyramid in
production. Key adaptations for this repo: single-package (no Turborepo), Drizzle ORM instead
of Kysely, Next.js App Router serves both frontend and API (no separate SPA + API servers).

## Decision Drivers

- **Must** validate Drizzle queries and migrations against a real database — mocks cannot catch
  query correctness or schema drift
- **Must** be runnable locally without any pre-provisioned infrastructure beyond Docker
- **Should** keep the unit test cycle fast (target: < 5 s) — integration/E2E run separately
- **Should** follow the same naming and config conventions as DigitalPostSandbox to ease
  cross-project knowledge transfer
- **Team familiarity** — the three-layer pyramid is already understood and maintained

## Considered Options

### Option 1: Unit tests only (Vitest + mocks)

- **Pros**: Fast, no infrastructure required, already partially set up
- **Cons**: Mocking Drizzle is unreliable and masks real query bugs; migrations may silently
  break without integration coverage

### Option 2: Unit + integration tests (Vitest, two configs)

- **Pros**: Real PostgreSQL validates queries and migrations; unit cycle stays fast
- **Cons**: Requires PostgreSQL for integration tests — solved with testcontainers locally

### Option 3: Unit + integration + E2E (Vitest + Playwright)

- **Pros**: Full coverage pyramid; browser tests catch UI regressions and validate complete
  user flows end-to-end
- **Cons**: E2E tests are the slowest feedback loop; adds Playwright as a dependency

## Decision

We will adopt a **three-layer testing pyramid**: unit tests (Vitest), integration tests (Vitest
with a separate config), and end-to-end tests (Playwright).

## Rationale

Option 3 gives the strongest confidence without over-investing upfront. Testcontainers means
integration tests require zero infrastructure setup locally. Playwright runs against the Next.js
dev server, keeping the E2E setup simple (one server, not two as in DigitalPostSandbox). The
config split preserves a fast unit loop while allowing integration tests to run sequentially,
which is required to prevent migration races across test files.

## Layer Definitions

### Layer 1 — Unit tests

| Property     | Value                                                     |
| ------------ | --------------------------------------------------------- |
| Config       | `src/vitest.config.ts` (existing)                         |
| Environment  | jsdom (React components) + Node (utilities, domain logic) |
| File naming  | `*.test.ts` / `*.test.tsx`                                |
| Scope        | Pure functions, React components, utilities, domain logic |
| Database     | None — `vi.mock()` for repository modules                 |
| Speed target | Suite < 5 s                                               |
| Command      | `npm test`                                                |

### Layer 2 — Integration tests

| Property    | Value                                                                                                                                       |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Config      | `src/vitest.integration.config.ts` (new)                                                                                                    |
| Environment | Node                                                                                                                                        |
| File naming | `*.integration.test.ts`                                                                                                                     |
| Scope       | Drizzle repository functions, migration correctness, schema invariants                                                                      |
| Database    | Ephemeral PostgreSQL via `@testcontainers/postgresql` locally; `TEST_DATABASE_URL` env var in CI to use a pre-provisioned service container |
| Execution   | `fileParallelism: false` — avoids migration races across test files                                                                         |
| Command     | `npm run test:integration`                                                                                                                  |

Tests call Drizzle repository functions directly (not through HTTP); they assert on rows
inserted, queried, and deleted against the real schema.

### Layer 3 — E2E tests

| Property    | Value                                                                                                                                         |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Config      | `playwright.config.ts` (new)                                                                                                                  |
| Tool        | Playwright — Chromium only                                                                                                                    |
| File naming | `e2e/**/*.spec.ts`                                                                                                                            |
| Scope       | Critical user journeys: workspace access, list/task CRUD, member operations                                                                   |
| Database    | Dedicated test PostgreSQL; global setup (`e2e/global-setup.ts`) applies Drizzle migrations and seeds fixture data                             |
| Web server  | Playwright `webServer` config starts `next dev` on a fixed port; `E2E_TEST=true` env flag enables test-only behaviours (e.g. bypassing OAuth) |
| CI retries  | 1 retry in CI (`retries: process.env.CI ? 1 : 0`)                                                                                             |
| Reporters   | `list` locally; `list` + JUnit XML in CI                                                                                                      |
| Command     | `npm run test:e2e`                                                                                                                            |

### Mutation testing (on-demand)

Stryker (`@stryker-mutator/vitest`) targets critical pure-function domain logic only — for
example task-status transition rules and permission predicates. **Not in CI.** Run manually
during development of high-risk logic to surface weak assertions.

## Consequences

### Positive

- Real database validates Drizzle queries and migration history — mocked tests cannot catch
  schema drift or query bugs
- Unit cycle stays fast; integration and E2E tests are explicitly opt-in during development
- testcontainers means zero infrastructure setup for local integration runs (no Docker Compose
  step required before testing)
- `*.integration.test.ts` naming keeps test types co-located with the code they test rather
  than split across a separate directory
- Consistent with DigitalPostSandbox — team already understands the pattern

### Negative

- Integration tests are slower than unit tests: container cold-start adds 10–20 s on a cold
  image cache
- E2E tests are the slowest feedback loop — require the Next.js dev server and a running
  PostgreSQL
- Playwright and `@testcontainers/postgresql` add dev dependencies

### Risks and mitigations

| Risk                                                         | Mitigation                                                                                                              |
| ------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------- |
| Container cold-start makes local integration tests feel slow | `TEST_DATABASE_URL` override lets developers point at the existing Docker Compose PostgreSQL instead of a new container |
| E2E flakiness from UI timing                                 | Prefer Playwright's `expect(locator).toBeVisible()` over `waitForTimeout`; 1 CI retry                                   |
| Migration races in integration tests                         | `fileParallelism: false` in integration config                                                                          |
| E2E tests depend on OAuth/auth flow                          | `E2E_TEST=true` env flag gates a test-only credential bypass (consistent with DigitalPostSandbox `E2E_TEST` pattern)    |

## Implementation Notes

1. **Integration config** — add `src/vitest.integration.config.ts`:
   - `include: ['src/**/*.integration.test.ts']`
   - `globalSetup: ['src/test-helpers/integration-db.ts']` — starts a `postgres:17` testcontainer
     or defers to `TEST_DATABASE_URL`; applies Drizzle migrations via `drizzle-kit migrate`
   - `fileParallelism: false`, `testTimeout: 30_000`, `hookTimeout: 60_000`

2. **E2E setup** — add `playwright.config.ts` at repo root:
   - `webServer: { command: 'npm run dev', port: 3000 }`
   - `globalSetup: './e2e/global-setup.ts'` — creates/migrates a separate test database and
     loads seed fixtures; skips setup in CI when the bootstrap step has already done it

3. **npm scripts** — add to `package.json`:

   ```
   "test:integration": "vitest run --config src/vitest.integration.config.ts"
   "test:e2e":         "playwright test"
   ```

4. **CI** — unit tests + integration tests run on every PR; E2E runs as a separate job (or
   against a preview deployment) before merge to `main`.

## Related Decisions

- ADR-0003: Use PostgreSQL as the Primary Database — integration and E2E tests depend on this
- ADR-0004: Data Access with a TypeScript Query Layer and Migrations — integration tests
  validate the Drizzle repository layer and migration history directly
- ADR-0001: Adopt Next.js as the Frontend Framework — E2E tests run Playwright against the
  Next.js dev server (`next dev`)
