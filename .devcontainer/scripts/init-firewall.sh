#!/usr/bin/env bash
# =============================================================================
# DevContainer Firewall Initialization
# Whitelist-based egress firewall using iptables + ipset.
# Runs on every container start (postStartCommand) with sudo.
#
# Adapted from the official Claude Code devcontainer:
# https://github.com/anthropics/claude-code/blob/main/.devcontainer/init-firewall.sh
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

echo "Configuring firewall..."

# =============================================================================
# Fail-closed: if anything goes wrong after flushing, lock down egress
# =============================================================================
trap 'iptables -P OUTPUT DROP 2>/dev/null; ip6tables -P OUTPUT DROP 2>/dev/null; echo "FIREWALL ERROR: fail-closed — all egress blocked"' ERR

# =============================================================================
# Preserve Docker DNS before flushing
# =============================================================================
DOCKER_DNS_RULES=$(iptables-save -t nat | grep "127\.0\.0\.11" || true)

# Flush existing rules (including FORWARD chain).
# When Docker-in-Docker is enabled, dockerd sets up FORWARD chain rules for
# container networking. Flushing them here is safe because:
# 1. DinD containers don't persist across devcontainer restarts
# 2. dockerd recreates FORWARD rules for any new containers started after this
# 3. The FORWARD DROP policy only affects packets not matching Docker's rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
ipset destroy allowed-domains 2>/dev/null || true

# =============================================================================
# IPv6: block all egress except loopback
# Docker Desktop typically disables IPv6 for containers, but Docker CE on Linux
# may not. Without these rules, egress via IPv6 bypasses the IPv4 firewall.
# =============================================================================
ip6tables -F 2>/dev/null || true
ip6tables -X 2>/dev/null || true
ip6tables -A OUTPUT -o lo -j ACCEPT 2>/dev/null || true
ip6tables -P OUTPUT DROP 2>/dev/null || true
echo "  IPv6 egress blocked (loopback allowed)"

# Restore Docker internal DNS resolution
if [ -n "$DOCKER_DNS_RULES" ]; then
    echo "  Restoring Docker DNS rules..."
    iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
    iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
    echo "$DOCKER_DNS_RULES" | xargs -L 1 iptables -t nat
fi

# =============================================================================
# Allow essential services first
# =============================================================================
# DNS (UDP + TCP — TCP is needed for responses >512 bytes, DNSSEC, and large record sets)
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
# Localhost (required for Docker-in-Docker, debug ports, local services)
iptables -A OUTPUT -o lo -j ACCEPT

# =============================================================================
# Build domain whitelist
# =============================================================================
ipset create allowed-domains hash:net

# --- Helper: resolve domain and add IPs to ipset ---
resolve_and_add() {
    local domain="$1"
    local ips
    ips=$(dig +noall +answer +short A "$domain" 2>/dev/null | grep -E '^[0-9]+\.' || true)
    if [ -z "$ips" ]; then
        echo "  WARNING: Failed to resolve $domain (skipping)"
        return 0
    fi
    while read -r ip; do
        if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            ipset add allowed-domains "$ip" 2>/dev/null || true
        fi
    done <<< "$ips"
}

# --- Helper: add CIDR range to ipset ---
add_cidr() {
    local cidr="$1"
    if [[ "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        ipset add allowed-domains "$cidr" 2>/dev/null || true
    fi
}

# =============================================================================
# Build shared domains file
# Written once by init, read by both init and the cron refresh script.
# Format: one domain per line. Lines starting with # are comments.
# =============================================================================
DOMAINS_FILE="/etc/firewall-domains.conf"
echo "  Building domain whitelist..."

cat > "$DOMAINS_FILE" << 'DOMAINS_CORE'
# Core domains (always allowed)
# GitHub (source control)
github.com
api.github.com
raw.githubusercontent.com
objects.githubusercontent.com
github-releases.githubusercontent.com
codeload.github.com
# npm registry
registry.npmjs.org
npm.pkg.github.com
# PyPI
pypi.org
files.pythonhosted.org
# Claude API
api.anthropic.com
claude.ai
statsig.anthropic.com
# VS Code marketplace, updates & Remote Server
marketplace.visualstudio.com
vscode.blob.core.windows.net
update.code.visualstudio.com
gallery.vsassets.io
az764295.vo.msecnd.net
vscode-unpkg.net
dc.services.visualstudio.com
default.exp-tas.com
# GitHub Copilot
copilot-proxy.githubusercontent.com
api.githubcopilot.com
api.individual.githubcopilot.com
copilot-telemetry.githubusercontent.com
# UV / Astral (Python tooling)
astral.sh
# Debian/Ubuntu package repos (allows apt-get install at runtime)
deb.debian.org
security.debian.org
cdn-fastly.deb.debian.org
DOMAINS_CORE

# --- Conditional: Docker Hub (Docker-in-Docker) ---
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
    cat >> "$DOMAINS_FILE" << 'DOMAINS_DOCKER'

# Docker Hub
registry-1.docker.io
auth.docker.io
production.cloudflare.docker.com
download.docker.com
hub.docker.com
# GitHub Container Registry (ghcr.io)
ghcr.io
pkg-containers.githubusercontent.com
DOMAINS_DOCKER
fi

# --- Conditional: Bun ---
if [ "${INSTALL_BUN:-false}" = "true" ]; then
    cat >> "$DOMAINS_FILE" << 'DOMAINS_BUN'

# Bun
bun.sh
DOMAINS_BUN
fi

# --- Conditional: Azure DevOps ---
if [ "${ALLOW_AZURE_DEVOPS:-false}" = "true" ]; then
    cat >> "$DOMAINS_FILE" << 'DOMAINS_AZURE_DEVOPS'

# Azure DevOps
dev.azure.com
ssh.dev.azure.com
aex.dev.azure.com
DOMAINS_AZURE_DEVOPS
fi

# --- Extra user-defined domains ---
# Set EXTRA_FIREWALL_DOMAINS in devcontainer.json → containerEnv.
#
# Format: Space-separated list of fully-qualified domain names (FQDNs).
#   - Bare domains only — no protocol, port, or path.
#   - Each domain is resolved to IP(s) via DNS A records at container start.
#   - Subdomains are NOT automatically included.
#   - Wildcards (*.example.com) are NOT supported.
#
# Example:
#   "EXTRA_FIREWALL_DOMAINS": "maven.mycompany.com nexus.internal.io"
if [ -n "${EXTRA_FIREWALL_DOMAINS:-}" ]; then
    echo "" >> "$DOMAINS_FILE"
    echo "# Custom domains (EXTRA_FIREWALL_DOMAINS)" >> "$DOMAINS_FILE"
    for domain in ${EXTRA_FIREWALL_DOMAINS}; do
        echo "$domain" >> "$DOMAINS_FILE"
    done
fi

chmod 644 "$DOMAINS_FILE"

# =============================================================================
# Resolve all domains from the shared file
# =============================================================================
echo "  Resolving domains..."
while IFS= read -r line; do
    # Skip comments and blank lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    resolve_and_add "$line"
done < "$DOMAINS_FILE"

# --- Fetch GitHub IP ranges from meta API (broader coverage) ---
echo "  Fetching GitHub IP ranges..."
gh_ranges=$(curl -s --connect-timeout 5 https://api.github.com/meta 2>/dev/null || true)
if [ -n "$gh_ranges" ] && echo "$gh_ranges" | jq -e '.web and .api and .git' >/dev/null 2>&1; then
    while read -r cidr; do
        add_cidr "$cidr"
    done < <(echo "$gh_ranges" | jq -r '(.web + .api + .git)[]' 2>/dev/null || true)
    echo "  GitHub IP ranges added"
else
    echo "  WARNING: Could not fetch GitHub meta API (falling back to DNS resolution only)"
fi

# =============================================================================
# Host network access
# =============================================================================
HOST_IP=$(ip route | grep default | awk '{print $3}')
if [ -n "$HOST_IP" ]; then
    HOST_NETWORK=$(ip route | grep -v default | grep "$(echo "$HOST_IP" | cut -d. -f1-2)" | awk '{print $1}' | head -1)
    if [ -z "$HOST_NETWORK" ] || ! [[ "$HOST_NETWORK" =~ / ]]; then
        HOST_NETWORK="${HOST_IP}/32"
    fi
    echo "  Host network: $HOST_NETWORK"
    iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT
else
    echo "  WARNING: Could not detect host IP"
fi

# =============================================================================
# Set default policies and final rules
# =============================================================================
iptables -P INPUT ACCEPT
iptables -P FORWARD DROP

# Add ACCEPT rules BEFORE setting OUTPUT DROP policy.
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT
# Reject everything else with immediate feedback
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

# NOW set OUTPUT policy to DROP — all ACCEPT rules are already in place
iptables -P OUTPUT DROP

# Disable the fail-closed trap now that the firewall is fully configured
trap - ERR

# =============================================================================
# Verification
# =============================================================================
echo "  Verifying firewall..."

# Should be BLOCKED
if curl --connect-timeout 3 -s https://example.com >/dev/null 2>&1; then
    echo "  ERROR: Firewall verification failed — able to reach example.com (should be blocked)"
    exit 1
fi
echo "  Blocked: example.com (expected)"

# Should be ALLOWED
if ! curl --connect-timeout 5 -s https://api.github.com/zen >/dev/null 2>&1; then
    echo "  WARNING: Cannot reach api.github.com (firewall may be too restrictive)"
else
    echo "  Allowed: api.github.com (expected)"
fi

# =============================================================================
# Periodic re-resolve cron (handles CDN IP rotation)
# =============================================================================
echo "  Setting up periodic DNS re-resolve..."

cat > /usr/local/bin/refresh-firewall.sh << 'REFRESH_EOF'
#!/usr/bin/env bash
# Additive DNS re-resolve for firewall ipset.
# Reads domains from the shared domains file written by init-firewall.sh.
set -euo pipefail

DOMAINS_FILE="/etc/firewall-domains.conf"
[ -f "$DOMAINS_FILE" ] || exit 0

resolve_and_add() {
    local domain="$1"
    local ips
    ips=$(dig +noall +answer +short A "$domain" 2>/dev/null | grep -E '^[0-9]+\.' || true)
    while read -r ip; do
        if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            ipset add allowed-domains "$ip" 2>/dev/null || true
        fi
    done <<< "$ips"
}

add_cidr() {
    local cidr="$1"
    if [[ "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        ipset add allowed-domains "$cidr" 2>/dev/null || true
    fi
}

while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    resolve_and_add "$line"
done < "$DOMAINS_FILE"

gh_ranges=$(curl -s --connect-timeout 5 https://api.github.com/meta 2>/dev/null || true)
if [ -n "$gh_ranges" ] && echo "$gh_ranges" | jq -e '.web and .api and .git' >/dev/null 2>&1; then
    while read -r cidr; do
        add_cidr "$cidr"
    done < <(echo "$gh_ranges" | jq -r '(.web + .api + .git)[]' 2>/dev/null || true)
fi
REFRESH_EOF

chmod +x /usr/local/bin/refresh-firewall.sh

CRON_LINE="*/30 * * * * /usr/local/bin/refresh-firewall.sh >> /tmp/firewall-refresh.log 2>&1"
( crontab -l 2>/dev/null | grep -v 'refresh-firewall' ; echo "$CRON_LINE" ) | crontab -
service cron start 2>/dev/null || true

echo "Firewall configured successfully (re-resolves every 30 min via cron)"
