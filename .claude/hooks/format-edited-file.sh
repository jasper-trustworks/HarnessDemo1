#!/usr/bin/env bash
# Claude PostToolUse hook (Write|Edit). Formats the edited file with Prettier at
# edit time. ESLint --fix is intentionally NOT run here — it is owned by the
# pre-commit lint-staged stage, so we avoid re-doing the slow per-file lint on
# every edit. Never blocks: always exits 0.
set -uo pipefail

DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
input="$(cat)"
f="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"

# Nothing to do if no path, file missing, or path is generated/ignored.
[ -z "$f" ] && exit 0
[ -f "$f" ] || exit 0
case "$f" in
  */node_modules/* | */.next/* | */out/* | */src/coverage/* | */src/db/migrations/*) exit 0 ;;
esac

cd "$DIR" 2>/dev/null || exit 0

# Format anything Prettier understands; --ignore-unknown skips unsupported types.
# --no-install keeps the firewall happy (prettier is already a devDependency).
# ESLint --fix is deliberately left to the pre-commit lint-staged stage.
npx --no-install prettier --write --ignore-unknown "$f" >/dev/null 2>&1 || true

exit 0
