#!/bin/bash
# ==============================
# Hermes Community Hub - Sync
# ==============================
# Fetches the latest index.json from the hub,
# compares with last-seen, and shows new skills.
#
# Called by: cron job (every 6 hours) or manually
# Calls: hub-notify.sh to evaluate relevance

set -e

HUB_DIR="$HOME/.hermes/hub"
SCRIPTS_DIR="$HUB_DIR/scripts"
LAST_SEEN="$HUB_DIR/last-seen.json"
REPO_DIR="$HUB_DIR/repo"
HUB_REPO="https://raw.githubusercontent.com/nous-hermeshub/hermes-community-hub/main"
HUB_GIT="https://github.com/nous-hermeshub/hermes-community-hub.git"

# Fetch latest index.json
INDEX=$(curl -sL "$HUB_REPO/index.json" 2>/dev/null)
if [ -z "$INDEX" ] || [ "$INDEX" = "null" ]; then
  echo "[hub-sync] Could not fetch index.json — skipping"
  exit 1
fi

# Update git repo
if [ -d "$REPO_DIR/.git" ]; then
  cd "$REPO_DIR" && git pull --ff-only --depth 1 2>/dev/null || true
else
  rm -rf "$REPO_DIR"
  git clone --depth 1 "$HUB_GIT" "$REPO_DIR" 2>/dev/null || true
fi

# Read last-seen
SEEN_SKILLS=$(cat "$LAST_SEEN" 2>/dev/null || echo '{}')

# Compare and find new skills
NEW_SKILLS=$(python3 -c "
import json, sys

current = json.loads('''$INDEX''')
seen = json.loads('''$SEEN_SKILLS''')

if isinstance(current, dict) and 'skills' in current:
    skills = current['skills']
elif isinstance(current, list):
    skills = current
else:
    skills = []

new = []
for s in skills:
    name = s.get('name', '')
    ver = s.get('version', '')
    if name not in seen or seen[name] != ver:
        new.append(s)

# Update last-seen
for s in skills:
    seen[s.get('name', '')] = s.get('version', '')

with open('$LAST_SEEN', 'w') as f:
    json.dump(seen, f, indent=2)

if new:
    print(json.dumps(new))
else:
    print('')
")

if [ -z "$NEW_SKILLS" ] || [ "$NEW_SKILLS" = "" ]; then
  echo "[hub-sync] No new skills found"
  exit 0
fi

echo "[hub-sync] Found $(echo "$NEW_SKILLS" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))") new skill(s)"

# Evaluate relevance and notify
if [ -f "$SCRIPTS_DIR/hub-notify.sh" ]; then
  bash "$SCRIPTS_DIR/hub-notify.sh" "$NEW_SKILLS"
fi