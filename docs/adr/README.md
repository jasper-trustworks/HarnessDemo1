# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) for this project.
ADRs capture significant architectural decisions: their context, options considered, and consequences.

## Index

| ADR                                                        | Title                                                    | Status   | Date       |
| ---------------------------------------------------------- | -------------------------------------------------------- | -------- | ---------- |
| [0001](0001-adopt-nextjs-as-frontend-framework.md)         | Adopt Next.js as the Frontend Framework                  | Accepted | 2026-05-26 |
| [0002](0002-rest-json-api-via-route-handlers.md)           | Expose a REST/JSON API via Route Handlers                | Proposed | 2026-05-26 |
| [0003](0003-postgresql-as-the-database.md)                 | Use PostgreSQL as the Primary Database                   | Accepted | 2026-05-26 |
| [0004](0004-data-access-with-orm-and-migrations.md)        | Data Access with a TypeScript Query Layer and Migrations | Accepted | 2026-05-26 |
| [0005](0005-authentication-and-workspace-authorization.md) | Authentication and Workspace-Scoped Authorization        | Proposed | 2026-05-26 |
| [0006](0006-static-code-analysis-with-sonarqube.md)        | Static Code Analysis with SonarQube                      | Accepted | 2026-05-27 |

## Creating a New ADR

1. Copy `template.md` to `NNNN-short-title.md` (zero-padded four-digit number)
2. Fill in every section — be honest about trade-offs and negatives
3. Open a PR; at least two senior engineers should review
4. On merge, update the index above and link any related ADRs

## Status values

| Status         | Meaning                           |
| -------------- | --------------------------------- |
| **Proposed**   | Under discussion                  |
| **Accepted**   | Decision made, implementing       |
| **Rejected**   | Considered but not adopted        |
| **Deprecated** | No longer relevant                |
| **Superseded** | Replaced by another ADR (link it) |

## Principles

- Write the ADR _before_ implementation starts, not after
- Accepted ADRs are immutable — write a new one to supersede, never edit in place
- Keep each ADR to one to two pages
- Rejected decisions are valuable — keep them so the team doesn't relitigate
