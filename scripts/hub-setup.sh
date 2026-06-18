#!/bin/bash
# ==============================
# Hermes Community Hub - Setup
# ==============================
# Run: curl -sL https://raw.githubusercontent.com/hermeshub/hermes-community-hub/main/scripts/hub-setup.sh | bash
#
# This script:
# 1. Creates ~/.hermes/hub/ directory structure
# 2. Installs hub-sync.sh and hub-install.sh
# 3. Sets up a cron job to check for new skills every 6 hours
# 4. Runs the first sync immediately

set -e

HUB_DIR="$HOME/.hermes/hub"
SCRIPTS_DIR="$HUB_DIR/scripts"
INSTALLED_DIR="$HUB_DIR/installed"
HUB_REPO="https://raw.githubusercontent.com/hermeshub/hermes-community-hub/main"
HUB_GIT="https://github.com/hermeshub/hermes-community-hub.git"

echo "========================================"
echo "  Hermes Community Hub — Setup"
echo "========================================"

# Create directories
mkdir -p "$SCRIPTS_DIR" "$INSTALLED_DIR"

# Download scripts
echo "[1/4] Downloading hub scripts..."
for script in hub-sync.sh hub-install.sh hub-notify.sh; do
  curl -sL "$HUB_REPO/scripts/$script" -o "$SCRIPTS_DIR/$script"
  chmod +x "$SCRIPTS_DIR/$script"
done

# Download last-seen tracker
echo '{}' > "$HUB_DIR/last-seen.json"

# Install cron job (every 6 hours)
echo "[2/4] Setting up cron job (checks every 6 hours)..."
CRON_JOB="0 */6 * * * $SCRIPTS_DIR/hub-sync.sh > $HUB_DIR/sync.log 2>&1"
# Remove old cron entry if exists, then add new one
(crontab -l 2>/dev/null | grep -v "hub-sync.sh" || true; echo "$CRON_JOB") | crontab -

# Run first sync
echo "[3/4] Running first sync now..."
bash "$SCRIPTS_DIR/hub-sync.sh"

# Git clone full repo for installs
echo "[4/4] Cloning full skill repository..."
if [ -d "$HUB_DIR/repo" ]; then
  cd "$HUB_DIR/repo" && git pull --ff-only 2>/dev/null || true
else
  git clone --depth 1 "$HUB_GIT" "$HUB_DIR/repo"
fi

echo ""
echo "========================================"
echo "  ✅ Hermes Community Hub is active!"
echo "========================================"
echo ""
echo "  New skills checked every 6 hours"
echo "  Check manually:    bash $SCRIPTS_DIR/hub-sync.sh"
echo "  Install a skill:   bash $SCRIPTS_DIR/hub-install.sh <skill-name>"
echo "  Skills installed:  $INSTALLED_DIR"
echo ""
echo "  Log:      $HUB_DIR/sync.log"
echo "  Last seen: $HUB_DIR/last-seen.json"
echo ""