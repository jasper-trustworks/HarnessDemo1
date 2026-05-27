# Learnings

Timestamped lessons from working on this project. Newest first.

<!-- Format: [yyyy-mm-dd] What went wrong → What to do instead → When it applies -->

[2026-05-27] [Feature: workspace] A task's route handler needed `getRequiredSession()` from `_lib/session.ts`, which didn't exist yet. The implementer had to either expand the scope fence mid-task or stub the file. → When a task creates a route handler that calls a helper from another module, explicitly list that helper file in the task's scope fence — even if it's a one-function stub. → Applies whenever a new route task depends on auth, logging, or other cross-cutting helpers that haven't been built yet.
