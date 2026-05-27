# =============================================================================
# DevContainer Dockerfile
# Supports: Node.js/NPM/Bun, Python/UV
# Node.js and Python are installed via DevContainer features
# =============================================================================

# -----------------------------------------------------------------------------
# Build Arguments - Project Identity
# Used for container naming, Docker labels, and distinguishing instances.
# -----------------------------------------------------------------------------
ARG PROJECT_NAME="devcontainer"

# -----------------------------------------------------------------------------
# Build Arguments - Installation Toggles (override in devcontainer.json)
# Safe defaults: everything off. devcontainer.json build.args enables what's needed.
# -----------------------------------------------------------------------------
ARG INSTALL_CLAUDE="false"
ARG INSTALL_BUN="false"
ARG INSTALL_GITNEXUS="false"
ARG INSTALL_JETBRAINS="false"
ARG INSTALL_DOCS_PIPELINE="false"
ARG ALLOW_NPM_SCRIPTS="true"
ARG ALLOW_BUN_SCRIPTS="true"
ARG ALLOW_AZURE_DEVOPS="false"
ARG ENABLE_DCT="false"

# Git identity is passed via containerEnv in devcontainer.json (not build args)
# to avoid leaking PII into image layers. post-create.sh reads it at runtime.

# -----------------------------------------------------------------------------
# Base Image
# -----------------------------------------------------------------------------
FROM mcr.microsoft.com/devcontainers/base:debian AS base

# Re-declare ARGs after FROM (they don't persist across stages)
ARG PROJECT_NAME
ARG INSTALL_CLAUDE
ARG INSTALL_BUN
ARG INSTALL_GITNEXUS
ARG INSTALL_JETBRAINS
ARG INSTALL_DOCS_PIPELINE
ARG ALLOW_NPM_SCRIPTS
ARG ALLOW_BUN_SCRIPTS
ARG ALLOW_AZURE_DEVOPS
ARG ENABLE_DCT

# Store build args as environment variables for runtime scripts.
ENV PROJECT_NAME=${PROJECT_NAME} \
    INSTALL_CLAUDE=${INSTALL_CLAUDE} \
    INSTALL_BUN=${INSTALL_BUN} \
    INSTALL_GITNEXUS=${INSTALL_GITNEXUS} \
    INSTALL_JETBRAINS=${INSTALL_JETBRAINS} \
    INSTALL_DOCS_PIPELINE=${INSTALL_DOCS_PIPELINE} \
    ALLOW_NPM_SCRIPTS=${ALLOW_NPM_SCRIPTS} \
    ALLOW_BUN_SCRIPTS=${ALLOW_BUN_SCRIPTS} \
    ALLOW_AZURE_DEVOPS=${ALLOW_AZURE_DEVOPS} \
    ENABLE_DCT=${ENABLE_DCT}

# -----------------------------------------------------------------------------
# System Setup
# -----------------------------------------------------------------------------
USER root

# Set noninteractive mode to prevent apt prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install base system dependencies and configure locales
RUN apt-get update && \
    apt-get -y install --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https \
    git \
    vim \
    jq \
    tree \
    htop \
    unzip \
    wget \
    locales \
    build-essential \
    # Firewall dependencies (iptables + ipset for egress whitelist)
    iptables \
    ipset \
    iproute2 \
    dnsutils \
    # Cron (periodic DNS re-resolve for firewall CDN IP rotation)
    cron \
    # Sandbox dependencies (bubblewrap + socat for Claude Code native sandbox)
    # Always installed (~200KB) so /sandbox is available without rebuild
    bubblewrap \
    socat && \
    # Generate locales
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen && \
    # Apply security updates
    apt-get upgrade -y && \
    apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    # Create docker group and add vscode user
    groupadd -f docker && usermod -aG docker vscode && \
    # Set default locale
    update-locale LANG=en_US.UTF-8

# -----------------------------------------------------------------------------
# GitHub CLI (gh)
# -----------------------------------------------------------------------------
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && \
    apt-get install -y --no-install-recommends gh && \
    apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Set locale environment variables
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Copy firewall initialization script
COPY scripts/init-firewall.sh /usr/local/bin/init-firewall.sh
RUN chmod +x /usr/local/bin/init-firewall.sh

# -----------------------------------------------------------------------------
# Bun - Installed as vscode user after USER switch (see below)
# ENV set conditionally to keep non-Bun images clean.
# -----------------------------------------------------------------------------
RUN if [ "${INSTALL_BUN}" = "true" ]; then \
    echo 'export BUN_INSTALL=/home/vscode/.bun' >> /etc/profile.d/bun.sh && \
    echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> /etc/profile.d/bun.sh && \
    chmod +x /etc/profile.d/bun.sh; \
    fi

# -----------------------------------------------------------------------------
# Node.js - Installed via DevContainer feature (ghcr.io/devcontainers/features/node)
# Node.js v22+ respects container memory limits automatically — no explicit
# --max-old-space-size needed. Override via containerEnv if you hit heap limits.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Python - Installed via DevContainer feature (ghcr.io/devcontainers/features/python)
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Claude Code CLI (Conditional)
# Installed via native installer in post-create script (requires Node.js at runtime)
# ENV set conditionally to keep non-Claude images clean.
# -----------------------------------------------------------------------------
RUN if [ "${INSTALL_CLAUDE}" = "true" ]; then \
    echo 'export CLAUDE_CONFIG_DIR=/home/vscode/.claude' >> /etc/profile.d/claude.sh && \
    chmod +x /etc/profile.d/claude.sh; \
    fi

# -----------------------------------------------------------------------------
# Docs Pipeline (Conditional)
# Sphinx + sphinx-needs + PlantUML + Graphviz toolchain used by the
# trustworks-plugins methodology plugins (refac, arch, discovery, workspace).
# Flip INSTALL_DOCS_PIPELINE=true in devcontainer.json build.args and rebuild to enable.
# Python packages (sphinx, sphinx-needs, etc.) are NOT installed here —
# each plugin's /setup-docs creates docs/.venv/ and pip-installs them on demand.
# -----------------------------------------------------------------------------
RUN if [ "${INSTALL_DOCS_PIPELINE}" = "true" ]; then \
    set -eux && \
    echo "Installing docs pipeline (graphviz, JRE, fonts)..." && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    graphviz \
    fonts-dejavu-core \
    default-jre-headless && \
    apt-get clean -y && rm -rf /var/lib/apt/lists/*; \
    fi

# -----------------------------------------------------------------------------
# UV Package Manager Installation
# -----------------------------------------------------------------------------
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /tmp/uv-binaries/
RUN cp /tmp/uv-binaries/uv /usr/local/bin/uv && \
    cp /tmp/uv-binaries/uvx /usr/local/bin/uvx && \
    chmod +x /usr/local/bin/uv /usr/local/bin/uvx && \
    rm -rf /tmp/uv-binaries

# UV environment variables
ENV UV_LINK_MODE=copy
ENV UV_CACHE_DIR=/home/vscode/.cache/uv

# -----------------------------------------------------------------------------
# Plugin Marketplace Seed Directory
# Marketplaces are cloned on the host by fetch-marketplaces.sh (initializeCommand)
# and COPYed into the image here. No git credentials enter the image.
# Rebuild the container to pick up the latest plugin versions.
# -----------------------------------------------------------------------------
RUN mkdir -p /opt/claude-seed/marketplaces
COPY .plugin-marketplace/ /opt/claude-seed/marketplaces/

# -----------------------------------------------------------------------------
# Directory Structure & Permissions
# -----------------------------------------------------------------------------
RUN mkdir -p \
    /home/vscode/.npm \
    /home/vscode/.cache/uv \
    /home/vscode/.cache/pip \
    /home/vscode/.local/bin \
    /workspace && \
    # Bun directory (conditional)
    if [ "${INSTALL_BUN}" = "true" ]; then \
    mkdir -p /home/vscode/.bun; \
    fi && \
    # Claude Code directories (conditional)
    if [ "${INSTALL_CLAUDE}" = "true" ]; then \
    mkdir -p /home/vscode/.claude /home/vscode/.cache/claude-code; \
    fi && \
    # GitNexus directory (conditional)
    if [ "${INSTALL_GITNEXUS}" = "true" ]; then \
    mkdir -p /workspace/.gitnexus; \
    fi && \
    chown -R vscode:vscode /home/vscode /workspace

# -----------------------------------------------------------------------------
# Final Configuration
# -----------------------------------------------------------------------------
# Reset to interactive mode
ENV DEBIAN_FRONTEND=dialog

# Switch to non-root user for security
USER vscode

# Bun is installed in post-create.sh (not here) to avoid stale binaries.
# The ~/.bun volume mount would mask a build-time Bun install — on rebuild,
# the old cached binary in the volume hides the freshly built one.
# Installing in post-create.sh runs AFTER volumes are mounted, ensuring the
# latest Bun binary is always used.

# Configure PATH for user
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/vscode/.bashrc

# Set working directory
WORKDIR /workspace

# Labels for documentation and container identification
LABEL org.opencontainers.image.title="${PROJECT_NAME}-devcontainer" \
    org.opencontainers.image.description="Development container for ${PROJECT_NAME}" \
    org.opencontainers.image.version="1.0.0" \
    devcontainer.project="${PROJECT_NAME}"
