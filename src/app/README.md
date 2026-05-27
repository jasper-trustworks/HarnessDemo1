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
│   ├── ui/                          # Primitives: Button, IconButton, Avatar, AvatarStack,
│   │   │                            #   Badge, Input, Checkbox, Icon
│   │   ├── Avatar.tsx
│   │   ├── Badge.tsx
│   │   ├── Button.tsx
│   │   ├── Checkbox.tsx
│   │   ├── Icon.tsx
│   │   └── Input.tsx
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
import { getRequiredSession } from "@/app/_lib/session";
import { getListsForWorkspace } from "@/db/lists";

export async function GET() {
  const session = await getRequiredSession();
  const lists = await getListsForWorkspace(session.workspaceId);
  return Response.json(lists);
}
```

## Design system

Design tokens, typography classes, and component CSS classes all live in `globals.css`. The Todoish handoff source is at `docs/Todoish-handoff.zip`. Full agent constraints are in `CLAUDE.md`.

### Tokens

Use CSS custom properties — never raw hex values.

```css
color: var(--ink-4); /* secondary text */
background: var(--paper); /* primary canvas #FAFAF7 */
border: 1px solid var(--border);
```

### Typography classes

```tsx
<h1 className="t-display t-italic">Nothing due today.</h1>
<h2 className="t-h">Q3 planning</h2>
<p  className="t-body t-muted">No tasks yet.</p>
<span className="t-label">Today</span>
<span className="t-mono">2s ago</span>
```

### UI primitives — import by direct path

```tsx
import { Button, IconButton } from "@/app/_components/ui/Button";
import { Avatar, AvatarStack } from "@/app/_components/ui/Avatar";
import { Badge } from "@/app/_components/ui/Badge";
import { Input } from "@/app/_components/ui/Input";
import { Checkbox } from "@/app/_components/ui/Checkbox";
import { Icon } from "@/app/_components/ui/Icon";
```

```tsx
<Button variant="primary">Add task</Button>
<Button variant="ghost" size="sm">Cancel</Button>
<IconButton icon="plus" label="Add task" />

<Badge tone="coral" dot>Live</Badge>
<Badge tone="cobalt">Selected</Badge>
<Badge square>v1.2</Badge>

<Avatar name="Maya Chen" size="lg" />
<AvatarStack people={members} max={4} activeId={currentUserId} />

<Input placeholder="What needs doing" value={v} onChange={…} />
<Checkbox done={task.done} onChange={setDone} />
<Icon name="check" size={16} />
```

## Dev commands

```bash
npm run dev                        # start dev server on http://localhost:3000
NODE_ENV=production npm run build  # production build
npm run format                     # Prettier — format all files in place
npm run format:check               # Prettier — check only (used in CI)
npm run lint                       # ESLint + SonarJS
npm test                           # Vitest unit tests
npm run test:coverage              # Vitest with lcov coverage → src/coverage/
npm run test:e2e                   # Playwright E2E tests (requires PostgreSQL)
npm run test:e2e:ui                # Playwright with interactive UI
```

The pre-commit hook (Husky + lint-staged) runs `prettier --write` and `eslint --fix` automatically on staged `.ts/.tsx` files before every commit. Commits are blocked if any non-auto-fixable lint errors remain.

## Testing

Three layers defined in ADR-0007:

| Layer       | Tool                     | Command                    | Scope                                        |
| ----------- | ------------------------ | -------------------------- | -------------------------------------------- |
| Unit        | Vitest                   | `npm test`                 | Components, utilities, domain logic — no DB  |
| Integration | Vitest (separate config) | `npm run test:integration` | Drizzle repository functions against real DB |
| E2E         | Playwright               | `npm run test:e2e`         | User journeys through the full Next.js app   |

**E2E prerequisites** — PostgreSQL must be running before `npm run test:e2e`:

```bash
docker compose -f docker-compose.postgres.yml up -d
npm run test:e2e
```

Global setup (`e2e/global-setup.ts`) creates a dedicated test database (`app_db_test`), applies all Drizzle migrations, and seeds fixture data. Playwright starts `next dev` on port 3001 (separate from the regular dev server on 3000). Override the database URL with `E2E_DATABASE_URL` if needed.

See `CLAUDE.md` in this directory for agent conventions and `src/db/README.md` for database setup.
