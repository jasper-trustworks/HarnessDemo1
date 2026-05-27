#!/usr/bin/env bash
# Bootstrap a git worktree so it can actually run. A fresh worktree shares git
# history but NOT gitignored artifacts, so it starts with no node_modules and no
# .env.local. Run this from INSIDE the target worktree (cd into it, or use
# EnterWorktree first).
#
# Steps:
#   1. Seed .env.local — copied from the main worktree's .env.local if present,
#      else from the tracked .env.local.example.
#   2. npm ci — fast here: the devcontainer's ~/.npm cache is a shared named volume.
#   3. (--db only) provision a dedicated Postgres database for this worktree and
#      point its DATABASE_URL at it, so diverging migrations don't stomp other
#      worktrees that share the single app_db. Migrations are then applied.
#
# Without --db, the worktree reuses the shared app_db (fine for read-mostly work).
#
# Usage:
#   scripts/worktree-bootstrap.sh            # .env.local + npm ci, shared DB
#   scripts/worktree-bootstrap.sh --db       # + dedicated DB auto-named from branch
#   scripts/worktree-bootstrap.sh --db NAME  # + dedicated DB with an explicit name
set -uo pipefail

PG_CONTAINER="HarnessDemo1-postgres"   # docker-compose.postgres.yml → container_name

log()  { echo "worktree-bootstrap: $*"; }
die()  { echo "worktree-bootstrap: ERROR: $*" >&2; exit 1; }

# ---- arg parsing ----------------------------------------------------------
WANT_DB=0
DB_NAME=""
case "${1:-}" in
  --db) WANT_DB=1; DB_NAME="${2:-}" ;;
  "")   ;;
  -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
  *)    die "unknown argument '$1' (try --help)" ;;
esac

# ---- locate worktrees -----------------------------------------------------
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository"

WT_DIR="$(git rev-parse --show-toplevel)"               # the worktree we're bootstrapping
MAIN_WT="$(cd "$(git rev-parse --git-common-dir)/.." && pwd)"  # main working tree (holds .git/)
WT_ENV="$WT_DIR/.env.local"

if [ "$WT_DIR" = "$MAIN_WT" ]; then
  log "note: running in the MAIN worktree ($WT_DIR), not a linked one — that's fine for npm ci."
fi

# ---- 1. seed .env.local ---------------------------------------------------
if [ -f "$WT_ENV" ]; then
  log ".env.local already present — leaving it untouched"
elif [ -f "$MAIN_WT/.env.local" ]; then
  cp "$MAIN_WT/.env.local" "$WT_ENV"
  log "seeded .env.local from main worktree"
elif [ -f "$WT_DIR/.env.local.example" ]; then
  cp "$WT_DIR/.env.local.example" "$WT_ENV"
  log "seeded .env.local from .env.local.example"
else
  die "no .env.local source found (neither $MAIN_WT/.env.local nor .env.local.example)"
fi

# ---- 2. install dependencies ----------------------------------------------
log "installing dependencies (npm ci)…"
( cd "$WT_DIR" && npm ci ) || die "npm ci failed"

# ---- 3. optional dedicated database ---------------------------------------
if [ "$WANT_DB" -eq 1 ]; then
  # Derive a safe DB name from the branch when one wasn't given.
  if [ -z "$DB_NAME" ]; then
    branch="$(git -C "$WT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo worktree)"
    slug="$(printf '%s' "$branch" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$//')"
    DB_NAME="app_db_${slug}"
  fi
  DB_NAME="${DB_NAME:0:63}"   # Postgres identifier limit

  docker ps --format '{{.Names}}' | grep -qx "$PG_CONTAINER" \
    || die "Postgres container '$PG_CONTAINER' is not running — start it with: docker compose -f docker-compose.postgres.yml up -d"

  # Rebuild DATABASE_URL by swapping the database segment of the existing one.
  src_url="$(grep -E '^DATABASE_URL=' "$WT_ENV" | head -1 | cut -d= -f2-)"
  [ -n "$src_url" ] || die "no DATABASE_URL in $WT_ENV to derive the connection from"
  base="${src_url%/*}"                 # e.g. postgresql://postgres:postgres@localhost:5432
  new_url="$base/$DB_NAME"

  exists="$(docker exec -i "$PG_CONTAINER" psql -U postgres -tAc \
    "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" 2>/dev/null)"
  if [ "$exists" = "1" ]; then
    log "database '$DB_NAME' already exists — reusing"
  else
    docker exec -i "$PG_CONTAINER" psql -U postgres -v ON_ERROR_STOP=1 \
      -c "CREATE DATABASE \"$DB_NAME\";" >/dev/null || die "CREATE DATABASE failed"
    log "created database '$DB_NAME'"
  fi

  # Point this worktree's .env.local at the dedicated DB.
  if grep -q '^DATABASE_URL=' "$WT_ENV"; then
    sed -i "s#^DATABASE_URL=.*#DATABASE_URL=${new_url}#" "$WT_ENV"
  else
    printf 'DATABASE_URL=%s\n' "$new_url" >> "$WT_ENV"
  fi
  log "DATABASE_URL → $new_url"

  log "applying migrations…"
  ( cd "$WT_DIR" && DATABASE_URL="$new_url" npm run db:migrate ) || die "db:migrate failed"
fi

log "done. Start the dev server with:  PORT=3001 npm run dev   (3000 is likely taken by another worktree)"
