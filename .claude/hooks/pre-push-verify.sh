#!/usr/bin/env bash
# Claude PreToolUse hook on Bash. Runs the full push gate ONLY when the command is
# a `git push`; everything else exits 0 immediately. The PreToolUse "Bash" matcher
# fires on every Bash call and the `if` matcher-filter proved unreliable in this
# harness, so the hook self-gates by parsing the command from its stdin payload.
# On a real push it delegates to scripts/verify-push.sh: exit 2 blocks the push and
# surfaces stderr to Claude; exit 0 lets it proceed.
set -uo pipefail

DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

# Self-gate: only act on `git push` (allows global flags like `git -c x push`).
cmd="$(cat | jq -r '.tool_input.command // empty' 2>/dev/null)"
if ! printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]])git[[:space:]]+(-[^[:space:]]+[[:space:]]+)*push([[:space:]]|$)'; then
  exit 0
fi

if bash "$DIR/scripts/verify-push.sh"; then
  exit 0
fi

echo "Push blocked: local verification (format:check + lint + test) failed. Fix the issues reported above, then push again." >&2
exit 2
