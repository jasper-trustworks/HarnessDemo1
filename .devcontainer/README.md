# HarnessDemo1 DevContainer

A secure development container for Node.js + Python + Bun with Docker-in-Docker, Claude Code, and GitNexus.

## Installed Runtimes

| Runtime | Package Manager | Version  |
| ------- | --------------- | -------- |
| Node.js | npm             | 24 (LTS) |
| Python  | uv, pip         | 3.14     |
| Bun     | bun             | latest   |

## Quick Start

Open the project in VS Code and select "Reopen in Container" when prompted.

## Architecture

```
.devcontainer/
├── devcontainer.json    # Single source of truth: build args, volumes, extensions, settings
├── Dockerfile           # Container image build with conditional runtime installs
├── .env.local.example   # Per-developer git identity template (copy to .env.local)
├── scripts/
│   ├── post-create.sh       # Runtime setup (package manager config, tool installation)
│   ├── init-firewall.sh     # Egress firewall (iptables whitelist, runs on every start)
│   └── fetch-marketplaces.sh # Plugin marketplace fetcher (runs on host before build)
└── README.md            # This file
```

**`devcontainer.json`** is the only configuration file you need to edit. It controls what gets installed (via `build.args`), what versions are used, what volumes are cached, and what IDE extensions are loaded.

## Configuration

All configuration is done in `devcontainer.json` via `build.args`:

### Installation Toggles

| Build Arg               | Current | Description                                                       |
| ----------------------- | ------- | ----------------------------------------------------------------- |
| `INSTALL_CLAUDE`        | `true`  | Install Claude Code CLI                                           |
| `INSTALL_BUN`           | `true`  | Install Bun runtime/package manager alongside Node.js             |
| `INSTALL_GITNEXUS`      | `true`  | Install GitNexus knowledge graph indexer and MCP server           |
| `INSTALL_JETBRAINS`     | `false` | Enable JetBrains Gateway support and firewall domain whitelisting |
| `INSTALL_DOCS_PIPELINE` | `false` | Install Sphinx pipeline system deps (graphviz + JRE + fonts)      |
| `ALLOW_NPM_SCRIPTS`     | `true`  | Allow NPM to run package scripts automatically                    |
| `ALLOW_BUN_SCRIPTS`     | `true`  | Allow Bun to run lifecycle scripts automatically                  |
| `ALLOW_AZURE_DEVOPS`    | `false` | Whitelist Azure DevOps hosts in the firewall                      |
| `ENABLE_DCT`            | `false` | Enable Docker Content Trust (image signature verification)        |
| `INSTALL_AGENT_DECK`    | `true`  | Install [agent-deck](https://github.com/asheshgoplani/agent-deck) (TUI session manager for AI agents) + tmux |

> `INSTALL_AGENT_DECK` pins the release via the `AGENT_DECK_VERSION` build arg (currently `1.9.38`). The binary is checksum-verified and installed to `/usr/local/bin/agent-deck`; its `tmux` dependency is installed in the same step (`jq` is already in the base image). Run `agent-deck` to launch it.

### Runtime Versions (via DevContainer Features)

Edit the `features` section in `devcontainer.json`:

```jsonc
"features": {
    "ghcr.io/devcontainers/features/node:1": {
        "version": "24"  // Options: "20", "22", "24", "lts", etc.
    },
    "ghcr.io/devcontainers/features/python:1": {
        "version": "3.14"  // Options: "3.11", "3.12", "3.13", "3.14", etc.
    }
}
```

### Resource Limits

Configured via `runArgs` in devcontainer.json:

```jsonc
"runArgs": [
    "--cpus=4",         // CPU limit
    "--memory=8g",      // Memory limit
    "--pids-limit=2048" // PID limit
]
```

## Git Identity

Each developer supplies their own git name/email via **`.devcontainer/.env.local`** (gitignored).

```bash
# From the project root:
cp .devcontainer/.env.local.example .devcontainer/.env.local
# Edit .env.local with your name and email.
```

`post-create.sh` sources the file on every container creation. If `.env.local` is missing, a boxed warning is printed on every start until it's created.

## Plugin Marketplace

Claude Code plugins are baked into the container image at build time.

1. `initializeCommand` runs `fetch-marketplaces.sh` on your **host** before the Docker build
2. The script clones marketplace repos into `.devcontainer/.plugin-marketplace/`
3. The Dockerfile COPYs them into `/opt/claude-seed/marketplaces/` inside the image
4. The script syncs `extraKnownMarketplaces` in `.claude/settings.json` automatically

### Adding or removing a marketplace

Edit the `MARKETPLACES` array in `fetch-marketplaces.sh` and rebuild:

```bash
MARKETPLACES=(
  "trustworks-plugins|https://github.com/trustworksdk/plugin-marketplace.git"
  "my-marketplace|https://github.com/myorg/my-plugins.git"
)
```

## Security Features

- **Egress firewall**: Whitelist-based iptables firewall (npm, PyPI, GitHub, Bun, Docker Hub, Claude API, VS Code marketplace, Debian repos). Runs on every start with periodic cron re-resolve every 30 min.
- **Non-root user**: Runs as `vscode` user
- **Resource limits**: CPU, memory, and PID limits via `runArgs`
- **NPM/Bun script control**: Enabled by default — egress firewall is primary protection
- **Native sandbox** (Claude Code): bubblewrap sandbox in `.claude/settings.json` with Docker excluded from sandbox
- **Privileged mode**: Required for Docker-in-Docker (`--privileged` in runArgs)

## Volume Mounts (Caching)

Named volumes persist across container rebuilds, scoped per devcontainer via `${devcontainerId}`:

| Volume          | Path                   | Purpose                        |
| --------------- | ---------------------- | ------------------------------ |
| `npm-cache`     | `~/.npm`               | NPM package cache              |
| `bun-cache`     | `~/.bun`               | Bun binary and cache           |
| `uv-cache`      | `~/.cache/uv`          | UV package cache               |
| `pip-cache`     | `~/.cache/pip`         | pip package cache              |
| `claude-config` | `~/.claude`            | Claude Code config             |
| `claude-cache`  | `~/.cache/claude-code` | Claude Code cache              |
| `gitnexus`      | `/workspace/.gitnexus` | GitNexus knowledge graph index |

## Port Mappings

| Port | Label         | Auto-Forward |
| ---- | ------------- | ------------ |
| 3000 | Node.js App   | Notify       |
| 5432 | PostgreSQL    | Silent       |
| 8000 | Python App    | Notify       |
| 9229 | Node.js Debug | Silent       |

## Troubleshooting

### Tool or package install fails with network errors

```bash
# Check for blocked connections
sudo iptables -L -n -v | grep -c REJECT
# See whitelisted domains
cat /etc/firewall-domains.conf
```

Add missing domains to `EXTRA_FIREWALL_DOMAINS` in `devcontainer.json` → `containerEnv`.

### Container fails to build

1. Ensure Docker has enough resources (8GB+ RAM)
2. Try `Dev Containers: Rebuild Container Without Cache`
3. Check build logs for specific errors

### Container name conflict

```bash
docker rm HarnessDemo1-devcontainer
```

Then retry "Reopen in Container".

### Database connection refused

```bash
docker compose -f docker-compose.postgres.yml up -d
```
