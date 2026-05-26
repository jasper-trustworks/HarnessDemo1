#!/usr/bin/env bash
# =============================================================================
# Fetch Plugin Marketplaces (SEED DIRECTORY)
#
# For users on the Trustworks Claude organization: plugins are delivered
# automatically via organization settings once Claude Code is authenticated.
# This script is NOT needed in that case.
#
# For users outside the TW Claude org (e.g. contractors, partners, or
# external devs with GitHub access): this script bakes plugins into the
# container image so they're available without a TW Claude account.
#
# Runs on the HOST via initializeCommand — before the container image is
# built. Clones plugin marketplace repos so the Dockerfile can COPY them
# into the image at build time. Git credentials stay on the host and never
# leak into the container image.
# =============================================================================
set -e

# ---------------------------------------------------------------------------
# Marketplace Registry
# Format: "marketplace-name|repo-url"
# The marketplace name becomes the directory name under the plugin seed dir.
# Add more entries to include additional marketplaces.
# ---------------------------------------------------------------------------
MARKETPLACES=(
  "trustworks-plugins|https://github.com/trustworksdk/plugin-marketplace.git"
)

# Directory where marketplaces are cloned (inside .devcontainer/, gitignored)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVCONTAINER_DIR="$(dirname "$SCRIPT_DIR")"
MARKETPLACE_DIR="$DEVCONTAINER_DIR/.plugin-marketplace"
mkdir -p "$MARKETPLACE_DIR"

for entry in "${MARKETPLACES[@]}"; do
  MARKETPLACE_NAME="${entry%%|*}"
  REPO_URL="${entry#*|}"
  TARGET_DIR="$MARKETPLACE_DIR/$MARKETPLACE_NAME"

  echo ""
  echo "=== Plugin marketplace: $MARKETPLACE_NAME ==="
  echo "    Source: $REPO_URL"

  # -------------------------------------------------------------------------
  # Verify access before attempting git operations
  # -------------------------------------------------------------------------
  while true; do
    if git ls-remote "$REPO_URL" HEAD &>/dev/null; then
      echo "    Access verified."
      break
    fi

    echo ""
    echo "    ERROR: Cannot access $REPO_URL"
    echo ""
    echo "    You need to authenticate with GitHub. Try one of:"
    echo ""
    echo "      Option 1 — GitHub CLI (recommended):"
    echo "        gh auth login"
    echo ""
    echo "      Option 2 — Personal access token:"
    echo "        Create a token with 'repo' scope at:"
    echo "        https://github.com/settings/tokens"
    echo "        Then configure git credentials."
    echo ""

    # Check if running interactively
    if [ -t 0 ]; then
      read -r -p "    Press Enter to retry after authenticating, or Ctrl+C to abort: "
    else
      echo "    Non-interactive mode — skipping this marketplace."
      echo "    The container will build without pre-loaded plugins."
      echo "    Authenticate with GitHub and rebuild to include plugins."
      continue 2
    fi
  done

  # -------------------------------------------------------------------------
  # Clone or update
  # -------------------------------------------------------------------------
  if [ -d "$TARGET_DIR/.git" ]; then
    echo "    Pulling latest changes..."
    if git -C "$TARGET_DIR" pull --ff-only --quiet 2>/dev/null; then
      echo "    Updated to $(git -C "$TARGET_DIR" rev-parse --short HEAD)"
    else
      echo "    Fast-forward failed (local divergence?). Re-cloning..."
      rm -rf "$TARGET_DIR"
      git clone --quiet "$REPO_URL" "$TARGET_DIR"
      echo "    Re-cloned at $(git -C "$TARGET_DIR" rev-parse --short HEAD)"
    fi
  else
    echo "    Cloning..."
    git clone --quiet "$REPO_URL" "$TARGET_DIR"
    echo "    Cloned at $(git -C "$TARGET_DIR" rev-parse --short HEAD)"
  fi
done

echo ""
echo "All plugin marketplaces are up to date."
echo ""

# =============================================================================
# Sync extraKnownMarketplaces in .claude/settings.json
#
# Single source of truth: the MARKETPLACES array above. This rewrites entries
# under .extraKnownMarketplaces whose source.path points into the seed
# directory (/opt/claude-seed/marketplaces/), while preserving any other
# user-managed entries and other top-level settings.
# =============================================================================
PROJECT_ROOT="$(dirname "$DEVCONTAINER_DIR")"
SETTINGS_FILE="$PROJECT_ROOT/.claude/settings.json"

if [ ! -f "$SETTINGS_FILE" ]; then
  echo "Skipping settings.json sync — $SETTINGS_FILE not found."
  echo "(Claude Code settings will not be auto-populated.)"
  echo ""
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo ""
  echo "ERROR: jq is required to sync .claude/settings.json but is not installed on the host."
  echo ""
  echo "  macOS:         brew install jq"
  echo "  Debian/Ubuntu: sudo apt-get install jq"
  echo "  Fedora/RHEL:   sudo dnf install jq"
  echo "  Windows:       choco install jq   (or: scoop install jq)"
  echo ""
  echo "Install jq and rebuild the container to sync plugin marketplaces into .claude/settings.json."
  exit 1
fi

# Build the object of seeded entries from the MARKETPLACES array.
SEEDED_JSON='{}'
for entry in "${MARKETPLACES[@]}"; do
  NAME="${entry%%|*}"
  SEEDED_JSON=$(jq --arg name "$NAME" '
    . + {
      ($name): {
        "source": {
          "source": "directory",
          "path": ("/opt/claude-seed/marketplaces/" + $name)
        }
      }
    }
  ' <<< "$SEEDED_JSON")
done

# Rewrite settings.json: drop existing seed-owned entries, add current ones,
# leave everything else (permissions, sandbox, other marketplaces) untouched.
TMP_SETTINGS=$(mktemp)
jq --argjson seeded "$SEEDED_JSON" '
  .extraKnownMarketplaces //= {}
  | .extraKnownMarketplaces |= with_entries(
      select((.value.source.path // "") | startswith("/opt/claude-seed/marketplaces/") | not)
    )
  | .extraKnownMarketplaces += $seeded
  | if (.extraKnownMarketplaces | length) == 0 then del(.extraKnownMarketplaces) else . end
' "$SETTINGS_FILE" > "$TMP_SETTINGS"

mv "$TMP_SETTINGS" "$SETTINGS_FILE"

echo "Synced .claude/settings.json: ${#MARKETPLACES[@]} seeded marketplace(s) in extraKnownMarketplaces."
echo ""
