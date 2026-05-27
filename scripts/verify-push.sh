#!/usr/bin/env bash
# Shared push-time verification — CI parity (format:check + lint + unit tests).
# Caches a pass keyed on the working-tree state (not just time) so a
# verify-then-push sequence doesn't double-run, while ANY change since the last
# pass forces a re-run. A time-only stamp would skip verification for code
# edited within the TTL window — letting unverified changes through both this
# Claude PreToolUse hook and the git-native .husky/pre-push, since both delegate
# here. Sonar is omitted (needs a server); E2E is omitted (needs Postgres + browsers).
set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 1

STAMP="$REPO_ROOT/.git/.verify-push-stamp"
TTL=300

# Fingerprint of everything that can change a format/lint/test outcome: the HEAD
# commit, tracked modifications (staged + unstaged) vs HEAD, and untracked,
# non-ignored files with their contents. Verification is read-only (format:check,
# lint, test all check rather than mutate), so the state sampled here is the state
# that passed — safe to record as the cache key after the run.
state_hash() {
  {
    git rev-parse HEAD 2>/dev/null || true
    git diff HEAD 2>/dev/null || true
    git ls-files --others --exclude-standard -z 2>/dev/null \
      | xargs -0 -r sha1sum 2>/dev/null || true
  } | sha1sum | awk '{print $1}'
}

CURRENT_HASH="$(state_hash)"

if [ -n "$CURRENT_HASH" ] && [ -f "$STAMP" ]; then
  age=$(($(date +%s) - $(stat -c %Y "$STAMP" 2>/dev/null || echo 0)))
  stamped_hash="$(cat "$STAMP" 2>/dev/null || true)"
  if [ "$age" -lt "$TTL" ] && [ "$stamped_hash" = "$CURRENT_HASH" ]; then
    echo "verify-push: cached pass (${age}s ago, tree unchanged) — skipping re-run"
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

printf '%s\n' "$CURRENT_HASH" > "$STAMP"
echo "verify-push: all checks passed"
exit 0
