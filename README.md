# Collaborative Todo Lists

A customer-facing application for creating and sharing todo lists and tasks within shared
workspaces. **Current state: scaffold in place — Next.js app and database layer exist;
feature implementation starts from here.**

**Stack:** TypeScript · Next.js 15 App Router ([ADR-0001](docs/adr/0001-adopt-nextjs-as-frontend-framework.md)) · PostgreSQL 17 ([ADR-0003](docs/adr/0003-postgresql-as-the-database.md)) · Drizzle ORM ([ADR-0004](docs/adr/0004-data-access-with-orm-and-migrations.md)) · Vitest.

Two sources of truth, split by topic:

- **Product** scope, domain model, and assumptions → [`.spec-lite/project.md`](.spec-lite/project.md)
- **Technical / architectural decisions** → [`docs/adr/`](docs/adr/) — the source of truth for _how_ the system is built. Other docs reference ADRs rather than restating them.
- Operating guide for AI agents working in this repo → [`CLAUDE.md`](CLAUDE.md)

## What's in this repo

| Path                          | What it is                                                                                   |
| ----------------------------- | -------------------------------------------------------------------------------------------- |
| `src/app/`                    | Next.js App Router — pages, layouts, Route Handlers                                          |
| `src/db/schema.ts`            | Drizzle schema — source of truth for the data model                                          |
| `src/db/client.ts`            | Drizzle client singleton (`db`)                                                              |
| `src/db/migrations/`          | Generated SQL migrations, applied with `npm run db:migrate`                                  |
| `src/drizzle.config.ts`       | drizzle-kit configuration                                                                    |
| `.env.local.example`          | Template for local env vars — copy to `.env.local`                                           |
| `.spec-lite/`                 | Product definition, domain model (Workspace/List/Task/Member), assumptions, feature tracking |
| `docs/adr/`                   | Architecture Decision Records, with index (`README.md`) and `template.md`                    |
| `docs/architecture/`          | C4 overview (System Context + Container diagrams) linking the ADRs                           |
| `agr.toml` / `agr.lock`       | Declared agent skills and their pinned versions                                              |
| `.claude/`                    | Claude Code project settings, enabled plugins, and synced skills                             |
| `.devcontainer/`              | Dev environment: Dockerfile, `devcontainer.json`, setup scripts                              |
| `docker-compose.postgres.yml` | PostgreSQL 17 service for local development                                                  |
| `CLAUDE.md`                   | Operating guide for AI agents working in this repo                                           |

## Getting started

```bash
# 1. Copy env template and fill in DATABASE_URL
cp .env.local.example .env.local

# 2. Start PostgreSQL
docker compose -f docker-compose.postgres.yml up -d

# 3. Install dependencies
npm install

# 4. Apply database migrations
npm run db:migrate

# 5. Run the dev server (requires NODE_ENV workaround — see CLAUDE.md)
npm run dev
```

Common scripts:

| Script                | What it does                                           |
| --------------------- | ------------------------------------------------------ |
| `npm run dev`         | Start Next.js dev server                               |
| `npm run build`       | Production build (`NODE_ENV=production npm run build`) |
| `npm test`            | Run Vitest once                                        |
| `npm run test:watch`  | Vitest in watch mode                                   |
| `npm run db:generate` | Generate a new migration from schema changes           |
| `npm run db:migrate`  | Apply pending migrations to the database               |
| `npm run db:studio`   | Open Drizzle Studio (database browser)                 |

## Tooling & Workflows

This repo is set up for agent-assisted development, in three layers.

### Agent skills (`agr`)

`agr` is a skill manager: it installs reusable Claude Code skills declared in `agr.toml`,
pinned to exact versions in `agr.lock`, into `.claude/skills/`. A **SessionStart hook** runs
`agr sync` automatically every session, so the declared skills are always present. 19 skills
are installed today, covering React/Next.js, backend, API design & security, PostgreSQL,
DDD/architecture, clean code, testing, auth, and accessibility.

- **Add a skill:** add its handle to the `dependencies` list in `agr.toml`, then run `agr sync`.
- **Remove a skill:** delete its line from `agr.toml` and run `agr sync`.
- `.claude/skills/` is gitignored — skills are fetched on demand, not vendored.

### Claude Code plugins

Plugins are enabled in `.claude/settings.json` and delivered via the Trustworks marketplace
and GitNexus (see [Plugin Marketplace](#plugin-marketplace) and
[GitNexus Knowledge Graph](#gitnexus-knowledge-graph) below for delivery details). Notable
plugins: `spec-lite`, `tw-code-review`, `socratic-ideation`, `arch`, `devcontainer-generator`,
and `gitnexus`, plus official plugins (`claude-md-management`, `typescript-lsp`,
`frontend-design`, `commit-commands`, `hookify`, `skill-creator`, `code-simplifier`,
`context7`).

### Development workflows

| To…                                    | Use                                                                           |
| -------------------------------------- | ----------------------------------------------------------------------------- |
| Plan and build a feature               | `spec-lite` — `/spec-lite:spec` → `/spec-lite:tasks` → `/spec-lite:implement` |
| Record an architecture / tech decision | the `architecture-decision-records` skill → write an ADR in `docs/adr/`       |
| Review changes before merge            | `tw-code-review`                                                              |
| Navigate / understand the codebase     | `gitnexus` (knowledge graph; re-index with `npx gitnexus analyze`)            |

## Development Environment

The rest of this guide documents the devcontainer-based development environment.

## Authenticating Claude Code

Run `claude` in the container terminal — it triggers the standard OAuth flow and saves credentials to `~/.claude/` (volume-mounted, so they persist across container restarts and rebuilds). No env vars needed.

### The paste-code fallback — important to know

Claude Code tries to open a browser and redirect back to a localhost callback after you sign in. Inside a container, that callback often can't complete:

- **VS Code devcontainers:** usually works via port forwarding, but port forwarding sometimes silently fails — browser shows "localhost refused to connect".
- **Claude CoWork / headless Docker sandbox:** no port forwarding, callback always fails.

When the callback can't complete, Anthropic's sign-in page automatically falls back to showing you a **login code**. The CLI prompts `Paste code here if prompted:` — copy the code from the browser and paste it back into the terminal. Auth completes the same way.

So the flow end-to-end:

1. Run `claude` in the container.
2. It prints an OAuth URL. If the browser doesn't open automatically, press `c` to copy the URL, then paste into your host browser.
3. Sign in on Anthropic.
4. Either the browser redirects back to localhost (great, done), or it shows a login code — paste the code into the CLI prompt.
5. Credentials are saved to `~/.claude/` and persist across rebuilds.

### Recommended: pre-authenticate on the host (most reliable)

Skip the in-container browser dance by generating the token **on the host** (where OAuth works reliably) and letting `devcontainer.json` propagate it in:

```bash
# On the HOST, not inside the container:
claude setup-token
# Copy the printed token, then:
echo 'export CLAUDE_CODE_OAUTH_TOKEN=<token>' >> ~/.zshrc    # or ~/.bashrc
# Reopen the devcontainer
```

`devcontainer.json` → `containerEnv` already includes `"CLAUDE_CODE_OAUTH_TOKEN": "${localEnv:CLAUDE_CODE_OAUTH_TOKEN}"`, so the host variable is passed through automatically. Inside the container, `claude` reads it at startup — no OAuth listener, no port forward, no race. Harmless when the host variable is unset.

### Running `claude setup-token` inside the container (CoWork / no host access)

If you can't set the token on the host, run `setup-token` from inside the container instead:

```bash
claude setup-token
echo 'export CLAUDE_CODE_OAUTH_TOKEN=<token>' >> ~/.bashrc
export CLAUDE_CODE_OAUTH_TOKEN=<token>
```

### Things that don't work

- `claude login --headless` — not a real flag.

## Git Identity

Each developer supplies their own git name/email via **`.devcontainer/.env.local`** — a gitignored file that lives with the devcontainer config. Nothing identity-related is committed; each teammate keeps their own copy.

### First-time setup

```bash
# From the project root:
cp .devcontainer/.env.local.example .devcontainer/.env.local
# Then edit .devcontainer/.env.local — for example:
cat > .devcontainer/.env.local <<'EOF'
export GIT_USER_NAME="Jasper Arildslund"
export GIT_USER_EMAIL="jasper.arildslund@trustworks.dk"
EOF
```

`post-create.sh` sources `/workspace/.devcontainer/.env.local` on every container creation and runs `git config --global user.name/email` with the values. Because the file lives on the bind-mounted workspace, it survives container rebuilds without any host-shell configuration — and it works in Claude CoWork (no host access required).

### Changing your identity later

Edit `.devcontainer/.env.local` and rebuild the container (or re-run `post-create.sh`).

### If `.env.local` is missing

`post-create.sh` prints a **prominent boxed warning** with a copy-pastable `cp .env.local.example .env.local` command and leaves git unconfigured. The warning re-prints on every container start until `.env.local` exists — it's hard to miss.

### Fallback: configure in-container (not persistent)

You can run `git config --global user.name "…"` / `user.email "…"` from inside the container, but `~/.gitconfig` is **not** volume-mounted, so those values do not survive a rebuild. `.env.local` is the durable mechanism.

## Configured Runtimes

| Runtime | Version | Package Manager |
| ------- | ------- | --------------- |
| Node.js | 24 LTS  | npm             |
| Python  | 3.14    | uv, pip         |
| Bun     | latest  | bun             |

## Rebuilding the Container

After changing `.devcontainer/` files:

- **VS Code:** `Dev Containers: Rebuild Container` from the command palette
- **CLI:** `docker build -f .devcontainer/Dockerfile --build-arg PROJECT_NAME=HarnessDemo1 --build-arg INSTALL_BUN=true --build-arg INSTALL_CLAUDE=true -t HarnessDemo1-devcontainer .`

## Configuration Files

| File                                          | Purpose                                                                  |
| --------------------------------------------- | ------------------------------------------------------------------------ |
| `.devcontainer/devcontainer.json`             | Single source of truth: build args, volumes, extensions, resource limits |
| `.devcontainer/Dockerfile`                    | Container image build with conditional runtime installs                  |
| `.devcontainer/scripts/post-create.sh`        | Runtime setup that runs after container creation                         |
| `.devcontainer/scripts/init-firewall.sh`      | Egress firewall — runs on every container start via postStartCommand     |
| `.devcontainer/scripts/fetch-marketplaces.sh` | Plugin marketplace fetcher — runs on host via initializeCommand          |
| `.devcontainer/.env.local.example`            | Per-developer git-identity template (committed) — copy to `.env.local`   |
| `.devcontainer/.env.local`                    | Your personal git name/email (gitignored, sourced by post-create.sh)     |
| `.claude/settings.json`                       | Claude Code config: permission mode, sandbox, marketplaces, plugins      |
| `agr.toml` / `agr.lock`                       | Declared agent skills and their pinned versions (synced by `agr sync`)   |
| `.spec-lite/project.md`                       | Product definition, domain model, assumptions, feature tracking          |
| `docs/adr/`                                   | Architecture Decision Records (index + template + accepted ADRs)         |

All configuration changes are made in `devcontainer.json` via `build.args`. The Dockerfile is the build recipe — you normally don't need to edit it.

## Adding or Removing Runtimes

### To add a runtime later:

1. Edit `devcontainer.json` → set the relevant `build.args` toggle to `"true"`
2. For Node.js/Python: add or update the entry in the `features` section
3. Rebuild the container

### To remove a runtime:

1. Set its `build.args` toggle to `"false"`
2. Remove its DevContainer feature entry (if applicable)
3. Remove related VS Code extensions from `customizations.vscode.extensions`
4. Remove related cache volume mounts from `mounts`
5. Rebuild the container

## Environment Persistence

This project has a persistent environment configured via `CLAUDE_ENV_FILE` (`/etc/sandbox-persistent.sh`).

- Environment variables stored in `/etc/sandbox-persistent.sh` persist across all bash invocations
- Use `echo "export VAR_NAME=value" >> /etc/sandbox-persistent.sh` to add persistent variables
- Use `bash -l -c "your-command"` to ensure the persistent environment is loaded

**CRITICAL: Never add shell completion scripts to the persistent environment file.** They will break the bash tool. Only add core initialization scripts (e.g., `nvm.sh`, `sdkman-init.sh`).

## Egress Firewall

The devcontainer includes a whitelist-based egress firewall that blocks all outbound traffic except explicitly allowed domains. This protects against supply-chain exfiltration (malicious npm/pip packages phoning home).

**Allowed by default:** npm, PyPI, GitHub, Claude API, VS Code marketplace, Bun, Docker Hub, and Debian repos.

**Adding custom domains** via `EXTRA_FIREWALL_DOMAINS` in `devcontainer.json` → `containerEnv`:

Format: space-separated fully-qualified domain names (FQDNs).

- Bare domains only — no protocol, port, or path (`maven.mycompany.com` not `https://maven.mycompany.com:443`)
- Subdomains listed individually — `example.com` does NOT include `sub.example.com`
- No wildcards — `*.example.com` is not supported (iptables resolves to IPs)

```jsonc
// In devcontainer.json → containerEnv
"EXTRA_FIREWALL_DOMAINS": "maven.mycompany.com nexus.internal.io api.corp.example.com"
```

After changing, restart the container (firewall re-runs on every start).

**Azure DevOps** — set `"ALLOW_AZURE_DEVOPS": "true"` in `devcontainer.json` → `build.args` to whitelist `dev.azure.com`, `ssh.dev.azure.com`, and `aex.dev.azure.com`. If your tooling still uses the legacy `<org>.visualstudio.com` URL form, also add that host to `EXTRA_FIREWALL_DOMAINS`.

**"WARNING: Failed to resolve …" during init** — these are not blocks. They mean DNS returned no IPs for that domain at that moment. The cron job re-resolves every 30 min and adds IPs additively as they become available.

## Claude Code Permission Mode

This devcontainer is configured with **auto mode** as the default permission mode (set in `.claude/settings.json`).

**Auto mode** uses a background safety classifier to review each action. It blocks prompt injection, unexpected deploys, and data exfiltration while letting routine dev work flow. Combined with the egress firewall, this provides defense-in-depth.

- Requires a Team plan and Sonnet/Opus 4.6
- Falls back to prompting if unavailable
- Configure trusted infrastructure via `autoMode.environment` in `.claude/settings.local.json` (NOT `.claude/settings.json` — the classifier ignores `autoMode` from shared project settings)

To change the mode: edit `.claude/settings.json` → `permissions.defaultMode`, or pass `--permission-mode <mode>` at startup.

## Native Sandbox

Claude Code's native sandbox (bubblewrap) is enabled and provides OS-level filesystem and network isolation for Bash commands. This complements the egress firewall:

- **Egress firewall** (iptables) — blocks network traffic to unauthorized domains
- **Native sandbox** (bubblewrap) — restricts Bash writes to allowed paths, blocks access to system files

The sandbox is configured in `.claude/settings.json` → `sandbox` section. Key settings:

- `autoAllowBashIfSandboxed: true` — sandboxed commands execute without permission prompts
- `failIfUnavailable: true` — hard-fails if sandbox can't start (prevents silent fallback to no protection)
- `allowWrite` includes `/workspace`, `/tmp`, and all common tool cache dirs (`~/.npm`, `~/.bun`, `~/.cache`, etc.) to prevent tools from failing

Docker commands are excluded from the sandbox (`excludedCommands`) because Docker requires direct socket access. These commands go through normal permission prompts instead.

To temporarily disable: `claude --no-sandbox`. To re-enable: edit `.claude/settings.json` or run `/sandbox`.

## Docker-in-Docker

Docker is available inside the container. You can run containers, use Docker Compose, and use tools like TestContainers.

- Docker commands work directly: `docker ps`, `docker compose up`
- The container runs in privileged mode (`--privileged` in runArgs) to support this
- To remove: delete the `docker-in-docker` feature and `--privileged` from runArgs

## PostgreSQL

PostgreSQL runs as a standalone container via Docker-in-Docker.

```bash
# Start PostgreSQL
docker compose -f docker-compose.postgres.yml up -d

# Stop (preserves data)
docker compose -f docker-compose.postgres.yml down

# Stop and wipe data
docker compose -f docker-compose.postgres.yml down -v
```

Connection: `postgresql://postgres:postgres@localhost:5432/app_db`

Set `DATABASE_URL` in `.env.local` to this value. Run `npm run db:migrate` after starting
PostgreSQL to apply schema migrations. `npm run db:studio` opens a browser-based database
browser (Drizzle Studio).

## Bun

Bun is installed alongside Node.js as an alternative runtime and package manager.

```bash
bun install          # Install dependencies (fast)
bun run <script>     # Run package.json scripts
bun test             # Run tests with Bun's test runner
```

Bun lifecycle scripts are enabled by default (same as NPM — the egress firewall is the primary protection). To disable, set `ALLOW_BUN_SCRIPTS` to `"false"` in build.args. Use `bun install --trust` to run scripts manually when disabled.

## GitNexus Knowledge Graph

GitNexus indexes the codebase into a knowledge graph, providing AI agents with architectural awareness. The GitNexus Claude plugin is configured via `.claude/settings.json` and provides MCP tools, search enrichment hooks, and guided workflow skills.

```bash
# Re-index after significant code changes
npx gitnexus analyze

# The plugin provides MCP tools automatically:
# query, context, impact, detect_changes, rename, cypher, list_repos
#
# Plus hooks (search enrichment, index freshness) and 7 skills:
# /gitnexus:gitnexus-guide, /gitnexus:gitnexus-exploring, /gitnexus:gitnexus-debugging,
# /gitnexus:gitnexus-impact-analysis, /gitnexus:gitnexus-refactoring, /gitnexus:gitnexus-pr-review
```

The knowledge graph is persisted in a named volume at `/workspace/.gitnexus` — it survives container rebuilds and only needs re-indexing when code changes significantly.

If the plugin wasn't installed automatically, Claude Code will prompt you on first launch (the marketplace is declared in `.claude/settings.json`). You can also install manually:

```bash
claude plugin install gitnexus@gitnexus-tools --scope project
```

## Plugin Marketplace

Claude Code plugins (Trustworks plugin marketplace) are delivered through two complementary mechanisms:

1. **Seed directory** (build-time) — plugins baked into the image, immediately available
2. **`extraKnownMarketplaces`** (runtime) — marketplace declared in `.claude/settings.json` with `"source": "directory"` pointing to the local copy, so it's visible in `claude plugin list`

Every `Rebuild Container` fetches the latest plugin versions automatically.

### How it works

1. `initializeCommand` runs `.devcontainer/scripts/fetch-marketplaces.sh` on your **host machine** before the Docker build
2. The script clones/updates marketplace repos into `.devcontainer/.plugin-marketplace/` using your local git credentials
3. The Dockerfile COPYs them into `/opt/claude-seed/marketplaces/` inside the image
4. `CLAUDE_CODE_PLUGIN_SEED_DIR` tells Claude Code where to find the pre-installed plugins
5. The script then syncs `extraKnownMarketplaces` in `.claude/settings.json` with the `MARKETPLACES` array (via `jq`)

**Git credentials never enter the container image** — authentication happens entirely on the host.

### First-time setup

If the fetch script fails with an access error, authenticate with GitHub on your host:

```bash
# Option 1 — GitHub CLI (recommended)
gh auth login

# Option 2 — Personal access token
# Create at https://github.com/settings/tokens with 'repo' scope
```

Then rebuild the container.

### Adding or removing marketplaces

The `MARKETPLACES` array in `.devcontainer/scripts/fetch-marketplaces.sh` is the **single source of truth**. Edit it and rebuild:

```bash
MARKETPLACES=(
  "trustworks-plugins|https://github.com/trustworksdk/plugin-marketplace.git"
  "my-marketplace|https://github.com/myorg/my-plugins.git"
)
```

## Troubleshooting

### Tool or package install fails with network errors

The egress firewall blocks all outbound traffic except whitelisted domains. If a tool fails silently or with connection errors:

1. Check for blocked connections: `sudo iptables -L -n -v | grep -c REJECT`
2. See what's whitelisted: `cat /etc/firewall-domains.conf`
3. Add missing domains to `EXTRA_FIREWALL_DOMAINS` in `devcontainer.json` → `containerEnv`
4. Restart the container (firewall re-runs on every start)

### Container fails to build

1. Ensure Docker has enough resources (recommend 8GB RAM minimum)
2. Try `Dev Containers: Rebuild Container Without Cache`
3. Check build logs for specific errors

### Permission errors

```bash
sudo chown -R vscode:vscode ~/.npm ~/.cache
```

### Node.js native module build fails

If you see `gyp ERR!` or similar:

```bash
sudo apt-get install -y build-essential python3-dev
npm rebuild
```

### Bun not found after rebuild

Re-run the install:

```bash
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc
```

### Python package missing system library

If pip install fails with linking errors:

```bash
sudo apt-get install -y lib<name>-dev
```
