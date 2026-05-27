# src/app — Next.js App Router

Pages, layouts, and API routes. Server Components by default (ADR-0001). All product API routes versioned under `/api/v1/` (ADR-0002).

## Folder structure

```
src/app/
│
├── (auth)/                          # Route group: unauthenticated pages
│   ├── layout.tsx                   # Redirects to /dashboard if already logged in
│   ├── login/
│   │   └── page.tsx
│   └── register/
│       └── page.tsx
│
├── (workspace)/                     # Route group: authenticated pages
│   ├── layout.tsx                   # Auth guard — redirects to /login if no session
│   ├── dashboard/
│   │   ├── page.tsx
│   │   └── _components/
│   │       └── WorkspaceSummary.tsx
│   ├── lists/
│   │   ├── page.tsx
│   │   ├── _components/
│   │   │   ├── ListGrid.tsx
│   │   │   └── CreateListButton.tsx
│   │   └── [listId]/
│   │       ├── page.tsx
│   │       ├── loading.tsx
│   │       └── _components/
│   │           ├── TaskList.tsx
│   │           └── CreateTaskForm.tsx
│   └── members/
│       ├── page.tsx
│       └── _components/
│           └── MemberTable.tsx
│
├── api/
│   ├── auth/
│   │   └── [...nextauth]/
│   │       └── route.ts             # Auth.js handler
│   └── v1/                          # Versioned REST API
│       ├── lists/
│       │   ├── route.ts             # GET (workspace lists)  POST (create)
│       │   └── [listId]/
│       │       ├── route.ts         # GET  PATCH  DELETE
│       │       └── tasks/
│       │           └── route.ts     # GET (tasks in list)  POST (create)
│       ├── tasks/
│       │   └── [taskId]/
│       │       └── route.ts         # GET  PATCH (status/assignee/due)  DELETE
│       └── members/
│           └── route.ts             # GET (workspace members)  POST (invite)
│
├── _components/                     # Shared UI components (non-routable)
│   ├── ui/                          # Primitives: Button, Input, Modal, Badge
│   └── layout/                      # AppShell, Sidebar, Header, Nav
│
├── _hooks/                          # Client-side hooks ('use client' only)
│   └── use-optimistic-task.ts
│
├── _lib/                            # Server-side app-layer utilities
│   └── session.ts                   # getRequiredSession() — redirects if unauthenticated
│
├── layout.tsx                       # Root layout
├── page.tsx                         # Landing page
└── globals.css
```

## Adding a page

Pages go in the appropriate route group. Every new `page.tsx` is a Server Component by default:

```
(workspace)/lists/page.tsx           → /lists
(workspace)/lists/[listId]/page.tsx  → /lists/:listId
(auth)/login/page.tsx                → /login
```

## Adding a component

- Used in **one route only** → `<route>/_components/MyComponent.tsx`
- Used in **two or more routes** → `src/app/_components/ui/` or `_components/layout/`
- Import by direct path — no barrel `index.ts` files

## Adding an API route

Add a `route.ts` under `src/app/api/v1/`. Always start with session resolution:

```ts
import { getRequiredSession } from '@/app/_lib/session'
import { getListsForWorkspace } from '@/db/lists'

export async function GET() {
  const session = await getRequiredSession()
  const lists = await getListsForWorkspace(session.workspaceId)
  return Response.json(lists)
}
```

## Dev commands

```bash
npm run dev                        # start dev server on http://localhost:3000
NODE_ENV=production npm run build  # production build
npm run lint                       # ESLint
npm test                           # Vitest
```

See `CLAUDE.md` in this directory for agent conventions and `src/db/README.md` for database setup.
