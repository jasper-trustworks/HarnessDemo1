---
name: ship-feature
description: One call — decompose a spec into tasks, implement every task, verify (done), and review a feature. Runs the spec-lite back-half unattended.
argument-hint: <feature-slug>
model: opus
allowed-tools: Read Write Edit Bash Grep Glob Agent Skill AskUserQuestion
---

# /ship-feature

Run the spec-lite back-half end to end for **one** feature, unattended:
decompose the spec into tasks → implement **every** task → verify & close (`done`) → `review`.
This wraps the four spec-lite commands; it does not reimplement them.

## Usage

```
/ship-feature <feature-slug>
```

`<feature-slug>` is optional. If omitted, resolve the single feature whose phase in
`.spec-lite/project.md`'s Active Features table is **before `done`** (e.g. `spec` or `tasks`).
If zero or several match, **halt** and list them so the user can pick.

## Preconditions

- The feature must already have a spec: `.spec-lite/features/<slug>/spec.md` must exist.
  If it is missing, **halt** and tell the user to run `/spec-lite:spec` first.
  This command never authors a spec.

## Autonomous mode (governing rule)

Run the entire pipeline without pausing. Wherever a wrapped sub-command would prompt the user
via `AskUserQuestion`, **do not prompt** — choose the recommended/default option and continue.
Emit one short progress line per phase. Halt only on the conditions in **Stop conditions**.
**Never run `git commit` or `git push`.**

## Process

### Phase 1 — Tasks

Invoke `Skill(spec-lite:tasks)` for the feature slug.
Autonomous override: accept the proposed task breakdown as-is ("Approve task breakdown") so it
writes `.spec-lite/features/<slug>/tasks.md`. Then read `tasks.md` and confirm ≥1 task exists.

### Phase 2 — Implement every task

Loop:

1. Read `.spec-lite/features/<slug>/tasks.md`. Parse each `### TASK-XXX` block and its
   `**Status**:` value (`pending` / `in-progress` / `done`).
2. If no task is `pending` → exit the loop.
3. Invoke `Skill(spec-lite:implement)` for the slug (it auto-selects the first `pending` task).
   Autonomous override: skip the "wait for plan approval" pause; proceed straight to dispatch.
4. When it returns, re-read `tasks.md`: the task must now be `done`, with passing-test evidence
   from the implementer. **No-progress guard:** if the same task is still `pending`/`in-progress`,
   or the implementer reports it could not reach green → **halt** (hard error).

### Phase 3 — Done (verify, with bounded fix loop)

Invoke `Skill(spec-lite:done)` for the slug.
Autonomous overrides:

- On test failures → choose **"Create fix tasks"**.
- On requirement gaps → choose **"Create coverage tasks"**.
  After it returns, re-read `tasks.md`. If new `pending` tasks were created → return to **Phase 2**
  to implement them, then run `done` again. Do **at most 3** done↔implement cycles. If tests still
  fail after the 3rd cycle → **halt** and report the failures (hard error). Proceed only when
  `done` reports the suite passing and sets the feature phase to `done` in `project.md`.

### Phase 4 — Review

Invoke `Skill(spec-lite:review)` for the slug.
Autonomous overrides:

- Apply the recommended project-memory updates and the recommended learnings curation
  (PROMOTE / KEEP / REMOVE / MERGE) without asking.
- For staleness findings: apply low-risk fixes; note higher-risk ones in the final report.
- Where review asks the user to _supply_ new learnings, contribute what you observed during
  this run (notable failures, retries, decisions); if nothing notable, skip.
- If review's code pass surfaces new quality/fix tasks, **do not loop back** — list them as
  follow-ups in the final report. Review is the terminal phase.

### Final report

Print a consolidated summary:

- Feature slug
- Tasks completed (count)
- Test result from `done` (e.g. "N passing")
- Review outcome: project memory / learnings updated; any follow-up fix tasks created
- A suggested commit message — but **do not commit** (the user commits when ready; the repo's
  pre-push-verify hook runs on push).

## Stop conditions (halt and report state)

Halt immediately — state the phase and reason, report current state (tasks done vs pending,
latest test status), and give the exact manual command to resume (e.g.
`/spec-lite:implement <slug> TASK-007`) — when:

- `spec.md` is missing or the slug can't be resolved.
- A `Skill(...)` invocation fails or is denied.
- The implementer cannot get a task's tests to green.
- The implement loop makes no progress (a task stays `pending`/`in-progress` after an attempt).
- `done` still reports failing tests after 3 done↔implement cycles.

## Rules

- One feature per run.
- The four spec-lite commands are the source of truth — invoke them; never reimplement their logic.
- Drive every loop decision from `.spec-lite/features/<slug>/tasks.md` (the `**Status**:` field)
  and `.spec-lite/project.md` (the Active Features phase), not from console text.
- Stay hands-off with version control: no `git commit`, no `git push`.

## See also

- `/spec-lite:tasks`, `/spec-lite:implement`, `/spec-lite:done`, `/spec-lite:review` — the wrapped steps
- `/spec-lite:spec` — run first if the feature has no spec yet
