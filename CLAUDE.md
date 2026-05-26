# DevContainer Configuration

## Claude Code Authentication

Run `claude` inside the container — standard OAuth, credentials saved to `~/.claude/` (volume-mounted, persists across rebuilds). When the browser can't redirect to the localhost callback (broken port forwarding, or CoWork/headless sandbox), the Anthropic sign-in page shows a login code instead — paste it into the CLI's `Paste code here if prompted:` prompt.

If subscription tokens keep expiring (~24h in some sandboxes) or you need non-interactive auth, use `claude setup-token` to get a 1-year token and add `export CLAUDE_CODE_OAUTH_TOKEN=<token>` to `~/.bashrc` (or `~/.zshrc`).

See "Authenticating Claude Code" in `README.md` for full details.

## Git Identity

Per-developer git name/email lives in `.devcontainer/.env.local` (gitignored). Each developer copies `.devcontainer/.env.local.example` to `.env.local` and edits it; `post-create.sh` sources the file on container creation and runs `git config --global`. The file lives on the bind-mounted workspace, so it survives rebuilds — no host-shell config needed.

If `.env.local` is missing, `post-create.sh` prints a prominent boxed warning on every container start with a copy-pastable `cp .env.local.example .env.local` command. If the user's git identity is unset inside the container, point them at `.devcontainer/.env.local.example` first; in-container `git config --global` is a fallback that does **not** survive rebuilds (`~/.gitconfig` is not volume-mounted). See "Git Identity" in `README.md` for details.

## Configured Runtimes

| Runtime | Version | Package Manager |
|---------|---------|-----------------|
| Node.js | 24 LTS | npm |
| Python | 3.14 | uv, pip |
| Bun | latest | bun |

## Environment Persistence

This project has a persistent environment configured via `CLAUDE_ENV_FILE` (`/etc/sandbox-persistent.sh`).

- Environment variables stored in `/etc/sandbox-persistent.sh` persist across all bash invocations
- Use `echo "export VAR_NAME=value" >> /etc/sandbox-persistent.sh` to add persistent variables
- Use `bash -l -c "your-command"` to ensure the persistent environment is loaded

**CRITICAL: Never add shell completion scripts to the persistent environment file.** They will break the bash tool. Only add core initialization scripts (e.g., `nvm.sh`, `sdkman-init.sh`).

## Egress Firewall

A whitelist-based egress firewall blocks all outbound traffic except explicitly allowed domains. If a tool or package install fails with network errors, the domain likely needs whitelisting.

- See whitelisted domains: `cat /etc/firewall-domains.conf`
- Check for blocked connections: `sudo iptables -L -n -v | grep -c REJECT`
- Add custom domains: edit `EXTRA_FIREWALL_DOMAINS` in `devcontainer.json` → `containerEnv` (space-separated FQDNs, bare domains only)
- Azure DevOps: set `ALLOW_AZURE_DEVOPS=true` in `devcontainer.json` → `build.args` (whitelists `dev.azure.com`, `ssh.dev.azure.com`, `aex.dev.azure.com`). Add `<org>.visualstudio.com` to `EXTRA_FIREWALL_DOMAINS` if you use the legacy URL form.
- "WARNING: Failed to resolve <domain>" during init is **not** a block — it just means DNS returned no IPs at boot. The cron job re-resolves every 30 min and adds IPs additively as they become available.

## Claude Code Permission Mode

This devcontainer is configured with **auto mode** as the default permission mode (set in `.claude/settings.json`).

**Auto mode** uses a background safety classifier to review each action. Combined with the egress firewall, this provides defense-in-depth.

- Requires a Team plan and Sonnet/Opus 4.6
- Falls back to prompting if unavailable
- Configure trusted infrastructure via `autoMode.environment` in `.claude/settings.local.json` (NOT `.claude/settings.json` — the classifier ignores `autoMode` from shared project settings)

To change: edit `.claude/settings.json` → `permissions.defaultMode`, or pass `--permission-mode <mode>` at startup.

## Native Sandbox

Claude Code's native sandbox (bubblewrap) provides OS-level filesystem and network isolation for Bash commands, complementing the egress firewall.

- Configured in `.claude/settings.json` → `sandbox` section
- `autoAllowBashIfSandboxed: true` — sandboxed commands execute without permission prompts
- `failIfUnavailable: true` — hard-fails if sandbox can't start

Docker commands are excluded from the sandbox (`excludedCommands`) because Docker requires direct socket access.

To temporarily disable: `claude --no-sandbox`.

## Configuration Files

| File | Purpose |
|------|---------|
| `.devcontainer/devcontainer.json` | Single source of truth: build args, volumes, extensions, resource limits |
| `.devcontainer/Dockerfile` | Container image build with conditional runtime installs |
| `.devcontainer/scripts/post-create.sh` | Runtime setup that runs after container creation |
| `.devcontainer/scripts/init-firewall.sh` | Egress firewall — runs on every container start via postStartCommand |
| `.devcontainer/.env.local.example` | Per-developer git-identity template (committed) — copy to `.env.local` |
| `.devcontainer/.env.local` | Per-developer git name/email (gitignored, sourced by post-create.sh) |

All configuration changes are made in `devcontainer.json` via `build.args`. The Dockerfile is the build recipe — you normally don't need to edit it.

See `README.md` for detailed usage documentation, troubleshooting, and how to add/remove runtimes.
