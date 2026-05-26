#!/usr/bin/env bash
# =============================================================================
# DevContainer Post-Create Script
# Runs after the container is created to perform runtime setup
# =============================================================================
set -e

echo "Running post-create setup..."

# =============================================================================
# Directory Ownership
# =============================================================================
echo "Ensuring directory permissions..."

directories=(
    "$HOME/.npm"
    "$HOME/.bun"
    "$HOME/.cache"
    "$HOME/.local"
    "$HOME/.config"
    "$HOME/.claude"
)

for dir in "${directories[@]}"; do
    if [ -d "$dir" ]; then
        # Heal ownership if the dir OR anything nested under it isn't owned by
        # vscode. Build-time tooling can seed a volume-mounted cache with
        # root-owned files (e.g. uv writing ~/.cache/uv/sdists-v9 during the
        # image build), leaving root-owned children under an otherwise
        # vscode-owned dir. A top-level-only stat check misses those, so the
        # cache stays unwritable. `find ... -quit` stops at the first offending
        # entry, so the recursive chown only runs when something needs fixing.
        if [ -n "$(find "$dir" ! -user vscode -print -quit 2>/dev/null)" ]; then
            sudo chown -R vscode:vscode "$dir" 2>/dev/null || true
        fi
    fi
done

# =============================================================================
# NPM Configuration
# =============================================================================
echo "Configuring NPM..."

if command -v npm &> /dev/null; then
    # Configure npm script security based on ALLOW_NPM_SCRIPTS
    if [ "${ALLOW_NPM_SCRIPTS:-false}" = "true" ]; then
        echo "  NPM scripts are ENABLED (ignore-scripts=false)"
        npm config set ignore-scripts false
    else
        echo "  NPM scripts are DISABLED for security (ignore-scripts=true)"
        echo "     To run scripts manually: npm run <script> --ignore-scripts=false"
        npm config set ignore-scripts true
    fi

    # Node is installed via the devcontainer `node` feature, which uses nvm.
    # nvm is incompatible with `prefix` / `globalconfig` in ~/.npmrc and emits
    # warnings on every shell startup if either is set. Heal any leftover entries.
    if [ -f "$HOME/.npmrc" ]; then
        sed -i '/^[[:space:]]*prefix[[:space:]]*=/d; /^[[:space:]]*globalconfig[[:space:]]*=/d' "$HOME/.npmrc"
    fi
    if [ -f "$HOME/.bashrc" ]; then
        sed -i '\|export PATH="\$HOME/\.npm-global/bin:\$PATH"|d' "$HOME/.bashrc"
    fi

    echo "  Node.js version: $(node --version)"
    echo "  NPM version: $(npm --version)"
fi

# =============================================================================
# Bun Configuration (Conditional)
# =============================================================================
if [ "${INSTALL_BUN:-false}" = "true" ]; then
    echo "Installing and configuring Bun..."

    # Install Bun as the vscode user (lands in ~/.bun).
    # Installed here (not in Dockerfile) because the ~/.bun volume mount would
    # mask a build-time install — on rebuild, the stale cached binary in the
    # volume hides the freshly built one. post-create.sh runs AFTER volumes
    # are mounted, so the install always succeeds.
    curl -fsSL https://bun.sh/install | bash

    # Ensure Bun is on PATH for this script and future shells
    if [ -d "$HOME/.bun/bin" ]; then
        if [[ ":$PATH:" != *":$HOME/.bun/bin:"* ]]; then
            export PATH="$HOME/.bun/bin:$PATH"
            echo 'export PATH="$HOME/.bun/bin:$PATH"' >> "$HOME/.bashrc"
        fi
    fi

    if command -v bun &> /dev/null; then
        # Configure bun script security based on ALLOW_BUN_SCRIPTS
        if [ "${ALLOW_BUN_SCRIPTS:-false}" = "true" ]; then
            echo "  Bun lifecycle scripts are ENABLED"
        else
            echo "  Bun lifecycle scripts are DISABLED for security"
            echo "     To run scripts manually: bun install --trust"
            if [ ! -f "$HOME/.bunfig.toml" ]; then
                cat > "$HOME/.bunfig.toml" << 'EOF'
[install]
# Disable lifecycle scripts by default for security.
# Use `bun install --trust` to run them when you trust the packages.
lifecycle = false
EOF
            fi
        fi

        echo "  Bun version: $(bun --version)"
    else
        echo "  WARNING: Bun installation failed. Try manually: curl -fsSL https://bun.sh/install | bash"
    fi
fi

# =============================================================================
# Claude Code CLI Installation (native install)
# =============================================================================
if [ "${INSTALL_CLAUDE:-false}" = "true" ]; then
    echo "Installing Claude Code CLI..."

    curl -fsSL https://claude.ai/install.sh | bash
    echo "  Claude Code CLI installed"
fi

# =============================================================================
# GitNexus Knowledge Graph (Conditional)
# Indexes the codebase into a knowledge graph for AI-powered code navigation.
# Requires Node.js (always installed via DevContainer feature).
# =============================================================================
if [ "${INSTALL_GITNEXUS:-false}" = "true" ]; then
    echo "Setting up GitNexus..."

    # Index the codebase (creates/updates .gitnexus/ in workspace root)
    if [ -d "/workspace" ] && [ "$(ls -A /workspace 2>/dev/null)" ]; then
        echo "  Indexing codebase..."
        cd /workspace && npx -y gitnexus@latest analyze 2>&1 || echo "  WARNING: GitNexus indexing failed (will retry on next container start)"
    else
        echo "  Workspace empty — skipping initial index. Run 'npx gitnexus analyze' after cloning your project."
    fi

    # Install the GitNexus Claude plugin (provides MCP + hooks + 7 skills).
    if [ "${INSTALL_CLAUDE:-false}" = "true" ] && command -v claude &> /dev/null; then
        echo "  Installing GitNexus Claude plugin..."
        claude plugin install gitnexus@gitnexus-tools --scope project 2>&1 \
            || echo "  INFO: Plugin auto-install skipped. Claude Code will prompt you to install when you first start a session."
    fi

    echo "  GitNexus setup complete"
fi

# =============================================================================
# Python/UV Configuration
# =============================================================================
echo "Configuring Python/UV..."

# Ensure /usr/local/bin/python (and python3) resolve to the active interpreter.
# The ghcr.io/devcontainers/features/python feature installs Python under
# /usr/local/python/current/bin and only adds that directory to PATH — it does
# NOT create /usr/local/bin/python. VS Code's Python extension expects an
# absolute path at /usr/local/bin/python, so we bridge it with a symlink.
PYTHON_BIN="$(command -v python3 || command -v python || true)"
if [ -n "$PYTHON_BIN" ]; then
    if [ "$PYTHON_BIN" != "/usr/local/bin/python3" ] && [ ! -e "/usr/local/bin/python3" ]; then
        sudo ln -sf "$PYTHON_BIN" /usr/local/bin/python3
        echo "  Linked /usr/local/bin/python3 -> $PYTHON_BIN"
    fi
    if [ "$PYTHON_BIN" != "/usr/local/bin/python" ] && [ ! -e "/usr/local/bin/python" ]; then
        sudo ln -sf "$PYTHON_BIN" /usr/local/bin/python
        echo "  Linked /usr/local/bin/python -> $PYTHON_BIN"
    fi
fi

# Verify UV installation
if command -v uv &> /dev/null; then
    echo "  UV version: $(uv --version)"

    # Install agr (Agent Resources) — the committed SessionStart hook in
    # .claude/settings.json runs `agr sync` to install the skills declared in
    # agr.toml. Installed here (not in the Dockerfile) so the binary lands in the
    # volume-mounted ~/.local/bin and survives rebuilds. Idempotent: a no-op when
    # agr is already present.
    echo "  Installing agr (agent-skills manager)..."
    uv tool install agr 2>&1 \
        || echo "  WARNING: 'uv tool install agr' failed — the SessionStart 'agr sync' hook will no-op until agr is installed."
fi

# Verify Python installation
if command -v python &> /dev/null; then
    echo "  Python version: $(python --version)"
fi

# =============================================================================
# Git Configuration
# =============================================================================
echo "Configuring Git..."

# Source per-developer overrides (git identity, personal env). This file is
# gitignored — copy .devcontainer/.env.local.example to .env.local to create it.
ENV_LOCAL="/workspace/.devcontainer/.env.local"
ENV_LOCAL_EXAMPLE="/workspace/.devcontainer/.env.local.example"
if [ -f "$ENV_LOCAL" ]; then
    echo "  Loading $ENV_LOCAL"
    # shellcheck disable=SC1090
    set -a; . "$ENV_LOCAL"; set +a
fi

# Apply git identity (populated by .env.local, or containerEnv if baked).
if [ -n "${GIT_USER_NAME}" ]; then
    git config --global user.name "${GIT_USER_NAME}"
    echo "  Git user.name: ${GIT_USER_NAME}"
fi
if [ -n "${GIT_USER_EMAIL}" ]; then
    git config --global user.email "${GIT_USER_EMAIL}"
    echo "  Git user.email: ${GIT_USER_EMAIL}"
fi

# Big warning when the per-developer .env.local mechanism is the intended
# path (example file exists) but the developer has not created their copy.
if [ -f "$ENV_LOCAL_EXAMPLE" ] && [ ! -f "$ENV_LOCAL" ]; then
    cat <<'WARN'

============================================================================

  WARNING: GIT IDENTITY NOT CONFIGURED

  .devcontainer/.env.local is missing. Git has no name/email — your
  next `git commit` will fail (or record an empty author).

  Quick setup — run in the project root (host or container):

      cp .devcontainer/.env.local.example .devcontainer/.env.local

  Then edit .devcontainer/.env.local and set your name + email.
  Re-run post-create.sh, or rebuild the container, to apply:

      bash .devcontainer/scripts/post-create.sh

  Details: README.md > Git Identity

============================================================================

WARN
elif [ -z "${GIT_USER_NAME}" ] && [ -z "${GIT_USER_EMAIL}" ]; then
    echo "  Git identity not configured. Set GIT_USER_NAME / GIT_USER_EMAIL"
    echo "  in devcontainer.json -> containerEnv, or run"
    echo "  'git config --global user.name/email' inside the container."
    echo "  See README.md -> Git Identity for details."
fi

git config --global --add safe.directory /workspace 2>/dev/null || true
git config --global pull.rebase true 2>/dev/null || true

# =============================================================================
# Docker Content Trust (Conditional)
# =============================================================================
if [ "${ENABLE_DCT:-false}" = "true" ]; then
    echo "  Docker Content Trust is ENABLED"
    echo 'export DOCKER_CONTENT_TRUST=1' >> "$HOME/.bashrc"
else
    echo "  Docker Content Trust is disabled (most images are unsigned)"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "=============================================="
echo "DevContainer Setup Complete! (${PROJECT_NAME:-devcontainer})"
echo "=============================================="
echo ""
echo "Installed Runtimes:"
echo "  Node.js + NPM"
echo "  Python + UV"
[ "${INSTALL_BUN:-false}" = "true" ] && echo "  Bun"
if [ "${INSTALL_CLAUDE:-false}" = "true" ]; then
    echo "  Claude Code CLI"
    if [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
        echo "    → Authenticated via CLAUDE_CODE_OAUTH_TOKEN"
    else
        echo "    → To authenticate: run 'claude' and follow the OAuth flow."
        echo "      If the browser shows 'localhost refused to connect', the sign-in"
        echo "      page will instead display a login code — paste it at the CLI's"
        echo "      'Paste code here if prompted:' prompt. Credentials are saved to"
        echo "      ~/.claude/ and persist across rebuilds via the claude-config volume."
        echo ""
        echo "      If subscription tokens keep expiring, use 'claude setup-token'"
        echo "      (1-year token) and add it to ~/.bashrc:"
        echo "        echo 'export CLAUDE_CODE_OAUTH_TOKEN=<token>' >> ~/.bashrc"
        echo ""
        echo "      See 'Authenticating Claude Code' at the top of README.md for details."
    fi
fi
if [ "${INSTALL_GITNEXUS:-false}" = "true" ]; then
    echo "  GitNexus (knowledge graph)"
    echo "    → Re-index with: npx gitnexus analyze"
fi
echo ""
