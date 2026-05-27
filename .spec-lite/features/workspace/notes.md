# Notes: Workspace Feature

## Intent

Auto-provision a single workspace for each user at registration. Scope is intentionally narrow:
single-user, no invite/sharing flow, no management UI (rename/delete). The workspace exists
to scope lists and tasks — nothing more at this stage.

## Key Decisions

- **Auto-created on sign-up** (not user-initiated). No "New Workspace" flow needed.
- **Atomic transaction**: user + workspace creation are a single DB transaction. Failure rolls back both.
- **One workspace per user**: multi-tenancy and workspace switching are explicitly out of scope.
- **No name input at creation**: workspace is auto-named; user-editable name is a future concern.
- **Sharing/members out of scope**: member invitation and access delegation deferred to a later feature.

## Assumptions

| #   | Assumption                                                                | Risk   | Status |
| --- | ------------------------------------------------------------------------- | ------ | ------ |
| A1  | Authentication (sign-up/login) exists before workspace feature is built   | medium | open   |
| A2  | One workspace per user — no multi-tenancy at launch                       | medium | open   |
| A3  | Workspace is auto-named (default name); no user-provided name at creation | low    | open   |
| A4  | No workspace management UI (rename/delete) in scope for this feature      | low    | open   |

## Adjacent Issues

Noted from TASK-002 implementation — do not fix here, file as separate tasks:

1. **No password authentication** — the `users` table has no `passwordHash` column and the
   registration payload is `{ email, name }` only. The endpoint is effectively unauthenticated
   at this stage. A future task must add credential storage (hashed password or OAuth token
   link) and protect all authenticated routes accordingly.

2. **No duplicate-email error shape** — when `createUserWithWorkspace` throws a unique-
   constraint violation (duplicate email), the route currently returns a generic
   `{ error: "Registration failed" }` 500. A follow-up should catch the specific Postgres
   error code (`23505`) and return a descriptive 409 Conflict instead.

3. **Vitest config does not include integration tests** — `src/vitest.config.ts` uses
   `include: ["src/**/*.test.{ts,tsx}"]`, which does not match `*.integration.test.ts` files.
   The integration tests need either a separate vitest config (e.g. `src/vitest.integration.config.ts`)
   or the include glob needs to be extended. Currently `npm test` will NOT pick up
   `route.integration.test.ts`.
