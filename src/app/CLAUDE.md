# App Layer (`src/app/`)

Agent instructions for this directory. See `README.md` for the developer overview.

## ADR constraints in force

**ADR-0001 (Next.js App Router):**
- Default every component to a **Server Component**; add `'use client'` only when you need event handlers or browser APIs.
- Use `cache: 'no-store'` for authenticated routes; add caching explicitly and deliberately.
- Pin the Next.js **minor** version in CI; review the changelog before upgrading.

**ADR-0002 (REST/JSON API):**
- All product API routes live under `/api/v1/` (versioned from day one).
- Route Handlers follow **parse → call repository → respond** — no business logic or raw DB access inline.
- Every authenticated Route Handler resolves the session first; `workspaceId` comes from the session, never from the request body or query string.

**ADR-0005 (Auth.js + workspace-scoped authorization):**
- Use `getRequiredSession()` from `_lib/session.ts` at the top of every authenticated Route Handler and server-fetching Server Component.
- Never trust a client-supplied workspace identifier — always derive it from the authenticated session.

## Folder conventions

### Route groups

| Group | URL | Purpose |
|-------|-----|---------|
| `(auth)/` | `/login`, `/register` | Unauthenticated pages. Layout redirects to `/dashboard` if a session already exists. |
| `(workspace)/` | `/dashboard`, `/lists`, `/members` | Authenticated pages. Layout calls `getRequiredSession()` and redirects to `/login` if unauthenticated. |

### Component placement

- **One route only** → colocate in `<route>/_components/` (underscore = non-routable in Next.js).
- **Two or more routes** → promote to `src/app/_components/`.
- `src/app/_components/ui/` — generic primitives (Button, Input, Modal, Badge).
- `src/app/_components/layout/` — structural shells (AppShell, Sidebar, Header).

Never create a barrel `index.ts` that re-exports components — import them by direct path. This keeps bundle splits clean and avoids tree-shaking failures.

### `_lib/session.ts`

Exports `getRequiredSession()`. Calls Auth.js `auth()`; throws a `redirect('/login')` if the session is missing. Import this at the top of every authenticated Route Handler and Server Component that needs user identity.

### `_hooks/`

Client-side React hooks only. Never import from `_hooks/` in a Server Component — hooks require `'use client'`.

### API route pattern

```ts
// src/app/api/v1/lists/route.ts
import { getRequiredSession } from '@/app/_lib/session'
import { getListsForWorkspace } from '@/db/lists'

export async function GET() {
  const session = await getRequiredSession()           // throws redirect if no session
  const lists = await getListsForWorkspace(session.workspaceId)
  return Response.json(lists)
}
```

### Compound components

Prefer compound components over boolean-prop monoliths (see `composition-patterns` skill). Lift shared state into a provider; UI sub-components consume context. Example pattern for `TaskList`:

```tsx
// _components/tasks/TaskList.tsx  ← Provider + sub-components in one file or folder
const TaskList = {
  Provider: TaskListProvider,
  Item: TaskItem,
  Empty: TaskListEmpty,
}
```

## Relevant skills

- `react-best-practices` — Server/Client component patterns, parallel data fetching, bundle optimization
- `react-component-performance` — avoiding unnecessary re-renders
- `composition-patterns` — compound components, provider pattern, no boolean-prop proliferation
- `web-design-guidelines` — accessibility and UI best practices
- `api-design-principles` — Route Handler design, resource-oriented paths
- `api-security-best-practices` — input validation, auth guards
