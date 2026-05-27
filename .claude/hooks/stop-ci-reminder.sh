#!/usr/bin/env bash
# Claude Stop hook. Non-blocking. If tracked, changed source files would fail
# `prettier --check`, surface a one-line reminder. Fast: only checks changed files.
set -uo pipefail

DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$DIR" 2>/dev/null || exit 0

# Changed tracked files (vs HEAD) limited to lintable types.
mapfile -t files < <(git diff --name-only HEAD 2>/dev/null | grep -E '\.(ts|tsx|js|jsx|json|md|css|ya?ml)$' || true)
[ "${#files[@]}" -eq 0 ] && exit 0

existing=()
for f in "${files[@]}"; do [ -f "$f" ] && existing+=("$f"); done
[ "${#existing[@]}" -eq 0 ] && exit 0

if ! npx --no-install prettier --check "${existing[@]}" >/dev/null 2>&1; then
  printf '{"systemMessage": "%d changed file(s) would fail CI format/lint. Run: npm run format && npm run lint"}\n' "${#existing[@]}"
fi
exit 0
