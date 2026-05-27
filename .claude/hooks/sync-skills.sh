#!/usr/bin/env bash
# Claude SessionStart hook. Syncs the agent skills declared in agr.toml (pinned
# by agr.lock) into .claude/skills/ via `agr sync`. Unlike a silenced one-liner,
# this logs the run to .claude/logs/agr-sync.log and surfaces a one-line warning
# to the session when sync fails — skills are injected as model instructions, so
# a failed/partial sync that leaves .claude/skills/ missing or stale must not be
# invisible. Never blocks the session: always exits 0.
set -uo pipefail

export PATH="$HOME/.local/bin:$PATH"

DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
LOG_DIR="$DIR/.claude/logs"
LOG="$LOG_DIR/agr-sync.log"
mkdir -p "$LOG_DIR" 2>/dev/null || true

# agr is installed by post-create's `uv tool install agr` into ~/.local/bin and
# may legitimately be absent on first boot — no-op quietly until it exists.
command -v agr >/dev/null 2>&1 || exit 0

# Cap log growth across sessions: keep the most recent ~500 lines.
if [ -f "$LOG" ] && [ "$(wc -l <"$LOG" 2>/dev/null || echo 0)" -gt 1000 ]; then
  tail -n 500 "$LOG" >"$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG" 2>/dev/null || true
fi

printf '=== agr sync @ %s ===\n' "$(date '+%Y-%m-%d %H:%M:%S')" >>"$LOG" 2>&1

if agr sync >>"$LOG" 2>&1; then
  exit 0
fi

# Non-blocking failure surface. systemMessage is shown to the user (same channel
# the Stop hook uses) without aborting startup. agr's own output went to the log.
printf '{"systemMessage": "agr sync failed — skills in .claude/skills/ may be missing or stale. See .claude/logs/agr-sync.log"}\n'
exit 0
