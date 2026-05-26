# Project: Collaborative Todo Lists

## Overview
A customer-facing collaborative todo list application that lets users create and share lists and tasks within a shared workspace.

## Tech Stack
- Language: TypeScript
- Framework: Next.js
- Test framework: Vitest (or Jest)
- Database: PostgreSQL

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
