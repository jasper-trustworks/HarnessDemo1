# Notes: Workspace UI

## Intent

Full journey: register → auto-create workspace → land on workspace home. Covers both the registration/onboarding flow and the post-login workspace dashboard view.

## Trigger

System event — pages are shown automatically at the right step in the flow (after registration succeeds; after login confirms an active session).

## Decisions

- REQ-001 does not include session establishment — auth is stubbed; session wiring is deferred to a future `auth` feature.
- Client-side redirect (Next.js router) after successful registration.
- Workspace home shows workspace name only — lists are a future feature.

## Assumptions

| #   | Assumption                                                                                     | Risk   | Status   |
| --- | ---------------------------------------------------------------------------------------------- | ------ | -------- |
| A1  | The registration API will return 409 (not 500) for duplicate emails — scoped into this feature | high   | resolved |
| A2  | Workspace home shows workspace name only at this stage — lists are a future feature            | medium | open     |
| A3  | Auth session is established by a future `auth` feature — this feature wires the UI only        | medium | open     |
| A4  | Client-side redirect (Next.js router) after successful registration                            | low    | open     |

## Adjacent Issues

<!-- Note things discovered during implementation that are out of scope -->
