# ADR-0006: Static Code Analysis with SonarQube

## Status

Accepted

## Context

As the codebase grows beyond scaffold and feature implementation begins in
earnest, the team needs a systematic way to surface code quality issues,
security vulnerabilities, and technical debt that are not caught by the
TypeScript compiler or Vitest tests alone.

Current tooling covers two dimensions:

- **Type safety** — the TypeScript compiler (`tsc`) catches type errors at
  build time.
- **Style and lightweight rules** — ESLint enforces formatting and a curated
  set of rules, but does not track trends, aggregated metrics, or duplication
  across the whole codebase.

What is missing is a continuous quality gate: a tool that tracks metrics over
time, detects OWASP-category vulnerabilities, measures test coverage
centrally, and blocks merges that regress quality below a defined threshold.
Without this, issues accumulate silently and surface only at review time or in
production.

## Decision Drivers

- **Quality gate on CI** — pull requests should be blocked if they introduce
  new critical or blocker issues, or drop coverage below a threshold
- **Security scanning** — detect OWASP Top 10 vulnerabilities (injection,
  XSS, insecure defaults) in TypeScript and server-side Route Handler code
- **Trend visibility** — track code smells, duplication, and technical debt
  over time, not just at the moment of review
- **TypeScript and Next.js support** — the analyser must understand the
  TypeScript AST and handle JSX/TSX without custom workarounds
- **Self-hosted option** — source code must not leave infrastructure we
  control; a managed cloud service is acceptable only if data residency can
  be guaranteed
- **Low ongoing maintenance** — a small team cannot operate a complex
  analysis cluster; the operational burden must be proportionate

## Considered Options

### Option 1: SonarQube Community Edition (self-hosted)

- **Pros**: industry standard; deep TypeScript and JavaScript analysis;
  OWASP security rules; tracks quality metrics and technical debt over
  time; quality gates built in; Docker image available for local and CI
  environments; free to self-host; integrates with GitHub PRs via
  SonarQube for GitHub
- **Cons**: requires running and maintaining a persistent SonarQube
  instance (PostgreSQL backend); Community Edition lacks branch analysis
  (PRs analysed, but feature-branch history not tracked separately);
  cold-start analysis can be slow on first run

### Option 2: SonarCloud (Sonar's hosted service)

- **Pros**: zero infrastructure to manage; branch analysis included on all
  tiers; native GitHub integration with PR decoration; always up to date
- **Cons**: source code sent to a third-party SaaS; free only for public
  repositories; private repositories require a paid subscription; data
  residency constraints may apply; vendor lock-in at the SaaS layer

### Option 3: ESLint-only (extend existing setup)

- **Pros**: already in place; no new tooling; `eslint-plugin-security` adds
  a security rule set; zero infrastructure overhead
- **Cons**: no historical trend tracking or dashboards; no quality gate on
  CI beyond pass/fail; duplication detection absent; coverage reporting
  requires a separate integration; does not replace a dedicated SAST tool
  for security scanning

### Option 4: CodeClimate / DeepSource

- **Pros**: hosted, low setup cost; reasonable TypeScript support;
  auto-fix suggestions (DeepSource)
- **Cons**: smaller rule sets than Sonar for security; less established
  for Next.js/TypeScript stacks; SaaS-only means source leaves our
  infrastructure; fewer integrations with our existing PostgreSQL and
  Docker tooling

## Decision

We will use **SonarQube Community Edition, self-hosted**, with the official
SonarQube Docker image backed by the existing PostgreSQL instance (ADR-0003).
Analysis will run in CI via the `sonar-scanner` CLI and results will be posted
back to GitHub pull requests. ESLint continues to run alongside SonarQube —
each tool handles what it does best.

## Rationale

SonarQube self-hosted satisfies the data-residency requirement: source code
does not leave our infrastructure. The Community Edition is free, and the
Docker image makes it straightforward to run in the same environment as the
rest of the stack. The PostgreSQL backend reuses the instance already chosen
in ADR-0003, keeping the operational footprint small.

SonarCloud is the natural alternative and removes all operational burden, but
it requires the source code to be uploaded to a third-party service and carries
a subscription cost for private repositories. This tradeoff is not justified at
the current team size.

Extending ESLint alone does not provide trend tracking, a configurable quality
gate, or duplication detection — exactly the capabilities that distinguish a
dedicated SAST tool from a linter. ESLint and SonarQube are complementary:
ESLint runs fast in the editor loop and in CI pre-analysis; SonarQube performs
the deeper scan and enforces the quality gate.

## Consequences

### Positive

- Pull requests blocked by a configurable quality gate (new blocker/critical
  issues, coverage regression) before merge
- Security vulnerabilities surfaced on every push, not discovered at review
  time or in production
- Historical quality metrics (code smells, duplication, debt) visible in the
  SonarQube dashboard over the lifetime of the project
- TypeScript, JSX/TSX, and Next.js Route Handler code analysed natively

### Negative

- A persistent SonarQube instance must be run and kept up to date (Docker
  Compose service or hosted VM)
- The PostgreSQL instance (ADR-0003) takes on a secondary workload; load is
  low but worth monitoring
- Community Edition does not track per-branch metrics independently — only
  the main branch and PR analyses are retained
- CI pipeline run time increases by the duration of the scanner step
  (typically one to three minutes for a codebase of this size)

### Risks and mitigations

| Risk                                                     | Mitigation                                                                                                                                          |
| -------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| SonarQube instance goes down, blocking CI                | Run quality gate as a non-blocking warning initially; promote to hard block once the service is proven stable                                       |
| PostgreSQL connection pool exhaustion from two workloads | Size the SonarQube connection pool conservatively; revisit if app-db latency increases                                                              |
| False positives causing alert fatigue                    | Tune the quality profile to the TypeScript ruleset; mark known false positives as `Won't Fix` in the UI rather than disabling rules globally        |
| Community Edition branch limitation                      | Acceptable at launch (A2 assumption: small team, single workspace); revisit with Developer Edition if branch-level trend tracking becomes necessary |
| Scanner step slows down PRs materially                   | Cache the `.sonar/cache` directory in CI; measure before optimising                                                                                 |

## Related Decisions

- ADR-0003: Use PostgreSQL as the Primary Database — SonarQube uses the same
  PostgreSQL instance for its own storage
- ADR-0004: Data Access with a TypeScript Query Layer and Migrations — query
  code in `src/db/` is in scope for SonarQube's security and duplication
  analysis
- ADR-0002: Expose a REST/JSON API via Route Handlers — Route Handlers are a
  primary surface for OWASP security rule evaluation
