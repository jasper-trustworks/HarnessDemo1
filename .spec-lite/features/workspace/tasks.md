# Tasks: Workspace

## Summary

4 tasks, ordered by risk. Each is a vertical slice (input → logic → persistence → output).

> **Schema note:** The existing `workspaces` table has no direct `user_id` FK — ownership is
> via the `members` join table. TASK-001 adds the FK to establish 1:1 ownership per
> assumption A2 (one workspace per user). Run `npm run db:generate` after TASK-001 to produce
> the migration; the agent cannot create migration files directly.

## Tasks

### TASK-001: Add workspace ownership column to schema

**Requirement**: REQ-001 (prerequisite)
**Status**: done
**Risk**: high
**Files**:

- `src/db/schema.ts` (modify) — add `userId` FK to `workspaces` table

**Plan**: Add a `user_id` FK to `workspaces` referencing `users.id`. Establishes 1:1 ownership needed for atomic creation (REQ-001) and the ownership check (REQ-004). Foundation for all other tasks. After editing the schema, run `npm run db:generate` to produce the migration.

---

### TASK-002: Atomic user + workspace registration

**Requirements**: REQ-001, REQ-005
**Status**: done
**Risk**: high
**Files**:

- `src/db/users.ts` (create) — `createUserWithWorkspace()` repository using `db.transaction()`
- `src/app/api/v1/auth/register/route.ts` (create) — `POST /api/v1/auth/register` endpoint
- `src/app/api/v1/auth/register/route.test.ts` (create) — unit tests (input validation)
- `src/app/api/v1/auth/register/route.integration.test.ts` (create) — integration: success creates both records; workspace DB failure rolls back both

**Plan**: A single `db.transaction()` inserts user + workspace atomically. The endpoint validates input, calls the repo, returns 201. If either insert fails, Drizzle rolls back both — no orphaned user records.

---

### TASK-003: Workspace retrieval + unauthenticated guard

**Requirements**: REQ-002, REQ-003
**Status**: done
**Risk**: medium
**Files**:

- `src/db/workspaces.ts` (create) — `getWorkspaceForUser(userId)` repository
- `src/app/api/v1/workspaces/me/route.ts` (create) — `GET /api/v1/workspaces/me` endpoint
- `src/app/api/v1/workspaces/me/route.integration.test.ts` (create) — integration: authenticated user gets 200 + workspace object; unauthenticated request gets 401

**Plan**: The handler calls `getRequiredSession()` (throws 401 if no session — REQ-003 covered), then queries the workspace by `userId`. Returns `{ id, name }` with 200. The unauthenticated 401 case is tested in the same file.

---

### TASK-004: Cross-user access guard

**Requirement**: REQ-004
**Status**: done
**Risk**: medium
**Files**:

- `src/db/workspaces.ts` (modify) — add `getWorkspaceById(workspaceId, userId)` scoped by `WHERE id = ? AND user_id = ?`
- `src/app/api/v1/workspaces/[workspaceId]/route.ts` (create) — `GET /api/v1/workspaces/:workspaceId` endpoint
- `src/app/api/v1/workspaces/[workspaceId]/route.integration.test.ts` (create) — integration: user A requesting user B's workspace ID gets 403

**Plan**: The scoped query returns `null` if the workspace doesn't exist or belongs to another user — the handler returns 403 Forbidden. The `AND user_id = ?` condition is the authorization boundary and cannot be bypassed by guessing an ID.
