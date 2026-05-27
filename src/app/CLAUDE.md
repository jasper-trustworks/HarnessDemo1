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

## Design system

All visual decisions — colors, type, spacing, radii, shadows, motion — live in `globals.css` as CSS custom properties. The source of truth is the Todoish handoff at `docs/Todoish-handoff.zip`.

### Tokens — always use variables, never raw values

```css
/* correct */
color: var(--ink-4);
background: var(--paper);
border: 1px solid var(--border);

/* wrong */
color: #5A5A55;
background: #FAFAF7;
```

Key semantic roles:

| Variable | Meaning |
|----------|---------|
| `--paper` / `--bg` | Primary canvas (`#FAFAF7`) |
| `--ink` / `--fg` | Primary text and controls |
| `--ink-4` / `--fg-muted` | Secondary text |
| `--ink-5` / `--fg-subtle` | Tertiary text, placeholders |
| `--coral` | Live/sync/presence signal — use sparingly |
| `--cobalt` | Links, focus rings, selected state — use sparingly |
| `--border` | Default hairline (`var(--ink-8)`) |
| `--bg-hover` | Row hover fill (`var(--ink-9)`) |
| `--bg-selected` | Selected row fill (`var(--cobalt-soft)`) |

**Color is rare.** A typical screen uses at most one saturated color on two or three elements. Never combine coral and cobalt at full saturation without a clear hierarchy.

### Typography

Use the `.t-*` utility classes for all text:

```tsx
<h1 className="t-display t-italic">Nothing due today.</h1>  // Instrument Serif italic
<h2 className="t-h">Q3 planning</h2>                        // Geist Semibold 28px
<p  className="t-body">Assign to someone</p>                // Geist Regular 15px
<span className="t-label">Today</span>                      // uppercase eyebrow
<span className="t-mono">2s ago</span>                      // Geist Mono metadata
```

Scale: `t-display-xl` · `t-display` · `t-display-sm` · `t-h` · `t-h-sm` · `t-body-lg` · `t-body` · `t-body-sm` · `t-label` · `t-mono` · `t-mono-xs`

Modifiers: `t-italic` · `t-muted` · `t-subtle` · `t-link`

**Copy rules (enforce in all UI text):**
- Sentence case everywhere — headlines, buttons, labels, menu items. Title Case only for proper nouns.
- No emoji — not in product, not in error states, not in empty states.
- No exclamation marks.
- Numerals over words: "3 tasks", not "three tasks".
- Short verbs in buttons: `Add task`, `Share`, `Archive`, `Mark done`.

### UI primitives

All primitives live in `src/app/_components/ui/`. Import by direct path — no barrel files.

```tsx
import { Button, IconButton } from '@/app/_components/ui/Button'
import { Avatar, AvatarStack } from '@/app/_components/ui/Avatar'
import { Badge } from '@/app/_components/ui/Badge'
import { Input } from '@/app/_components/ui/Input'
import { Checkbox } from '@/app/_components/ui/Checkbox'
import { Icon } from '@/app/_components/ui/Icon'
```

**Button variants:** `default` (outlined), `primary` (ink fill), `ghost` (no border), `danger`  
**Button sizes:** `sm` (26px), `md` (32px, default), `lg` (40px)  
**Badge tones:** `default`, `cobalt`, `coral`, `success`, `warn`, `danger`, `ink`, `outline`; add `square` for monospace tag style  
**Icon names:** `plus` · `search` · `bell` · `settings` · `check` · `chevR/L/D` · `more` · `moreV` · `close` · `inbox` · `today` · `list` · `folder` · `share` · `archive` · `clock` · `user` · `users` · `msg` · `flag` · `paperclip` · `arrowRight`

Use `IconButton` (not `Button` with an icon prop) for icon-only controls — it sets `aria-label` automatically.

### CSS component classes

Shared chrome is in `globals.css`. Use these classes directly on HTML elements when building new layout or before extracting to a component:

| Class | Use |
|-------|-----|
| `.btn` | Base button (combine with `.primary`, `.ghost`, `.danger`, `.sm`, `.lg`, `.icon`) |
| `.chip` | Badge/tag (combine with `.cobalt`, `.coral`, `.success`, `.warn`, `.danger`, `.ink`, `.outline`, `.sq`) |
| `.avatar` | Initials avatar circle (combine with `.lg`, `.xl`) |
| `.avatar-stack` | Overlapping avatar row |
| `.input` | Text input with focus ring |
| `.checkbox` | Circular task checkbox (combine with `.done`) |
| `.task-row` | 5-column task list row with hover and selected states |
| `.card` | White card with border and `--r-lg` radius |
| `.panel` | White panel with `--shadow-pop` |
| `.eyebrow` | Uppercase section label |
| `.divider` | 1px horizontal rule (`.strong` for heavier weight) |

### Visual rules

- **No gradients.** No glassmorphism. No blur.
- **No shadows on resting buttons, inputs, or cards.** `--shadow-pop` is for popovers/dropdowns; `--shadow-lift` for modals/toasts only.
- **Radii:** `--r-sm` (6px) on controls and chips; `--r-lg` (12px) on cards, panels, modals; `--r-pill` (999px) on avatars and badges; 0px on page edges and section dividers.
- **Focus rings** must always be visible: `outline: 2px solid var(--cobalt); outline-offset: 2px`.
- **Hover** on interactive rows: `background: var(--bg-hover)`. **Press** on buttons: darkens ~8%, no scale.
- **Animation defaults:** `var(--ease-out)` / `var(--dur-base)` (180ms). Page transitions use `var(--dur-slow)` (320ms).
- **Icons:** Lucide-style via the `Icon` component. 16px in body UI, 20px in toolbars. Stroke 1.5. No icon containers or backgrounds.

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
