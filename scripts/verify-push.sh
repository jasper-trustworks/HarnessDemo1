#!/usr/bin/env bash
# Shared push-time verification — CI parity (format:check + lint + unit tests).
# Caches a pass stamp for 300s so a verify-then-push sequence doesn't double-run.
# Called by both .husky/pre-push (git-native) and the Claude PreToolUse hook
# (.claude/hooks/pre-push-verify.sh). Sonar is omitted (needs a server); E2E is
# omitted (needs Postgres + browsers).
set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 1

STAMP="$REPO_ROOT/.git/.verify-push-stamp"
TTL=300

if [ -f "$STAMP" ]; then
  age=$(($(date +%s) - $(stat -c %Y "$STAMP" 2>/dev/null || echo 0)))
  if [ "$age" -lt "$TTL" ]; then
    echo "verify-push: cached pass (${age}s ago, TTL ${TTL}s) — skipping re-run"
    exit 0
  fi
fi

run_step() {
  echo "verify-push: running '$*'"
  if ! "$@"; then
    echo "verify-push: FAILED at '$*'" >&2
    exit 1
  fi
}

run_step npm run format:check
run_step npm run lint
run_step npm test

touch "$STAMP"
echo "verify-push: all checks passed"
exit 0
