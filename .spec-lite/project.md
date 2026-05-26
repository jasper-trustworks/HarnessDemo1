# Project: Collaborative Todo Lists

## Overview
A customer-facing collaborative todo list application that lets users create and share lists and tasks within a shared workspace.

## Tech Stack

Technical decisions live as Architecture Decision Records in [`docs/adr/`](../docs/adr/) —
the **source of truth**. This list is a pointer, not a second copy: see each ADR for the
decision, its rationale, and its constraints.

- Framework: Next.js (App Router) — [ADR-0001](../docs/adr/0001-adopt-nextjs-as-frontend-framework.md)
- Language: TypeScript — no ADR yet (working assumption)
- Database: PostgreSQL — no ADR yet (working assumption)
- Test framework: Vitest — no ADR yet (working assumption)

## Key Conventions
None established yet.

## Domain Concepts
| Term | Definition |
|------|------------|
| Workspace | Top-level container scoped to a team or organization; members share access |
| List | Named collection of tasks within a workspace (e.g. "Shopping", "Work tasks") |
| Task | Individual to-do item with title, status, optional due date and assignee |
| Member | User who belongs to a workspace and can view/edit its lists and tasks |

## Assumptions
| # | Assumption | Risk | Status |
|---|-----------|------|--------|
| A1 | Next.js can handle real-time collaboration (polling or WebSocket) | high | open |
| A2 | One user belongs to one workspace — no multi-tenancy at launch | medium | open |
| A3 | Tasks don't need sub-tasks or dependencies at launch | low | open |

## Active Features
| Feature | Phase | Tasks Done |
|---------|-------|------------|
| (none yet) | — | — |
