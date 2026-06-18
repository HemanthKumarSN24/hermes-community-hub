#!/bin/bash
# ==============================
# Hermes Community Hub - Install
# ==============================
# One-click install a skill from the hub
# Usage: bash hub-install.sh <skill-name>
#        bash hub-install.sh list          # list available skills
#        bash hub-install.sh search <term> # search skills

set -e

HUB_DIR="$HOME/.hermes/hub"
REPO_DIR="$HUB_DIR/repo"
INSTALLED_DIR="$HUB_DIR/installed"
HERMES_SKILLS="$HOME/.hermes/skills"

show_list() {
  echo ""
  echo "Available skills in the hub:"
  echo "---------------------------"
  if [ -f "$REPO_DIR/index.json" ]; then
    python3 -c "
import json
with open('$REPO_DIR/index.json') as f:
    data = json.load(f)
skills = data.get('skills', []) if isinstance(data, dict) else data
for s in skills:
    print(f\"  {s['name']:<30} v{s.get('version','?')}  {s.get('description','')}\")
"
  else
    echo "  No index found. Run hub-sync.sh first."
  fi
}

show_search() {
  local term="$1"
  echo ""
  echo "Search results for '$term':"
  echo "---------------------------"
  if [ -f "$REPO_DIR/index.json" ]; then
    python3 -c "
import json
with open('$REPO_DIR/index.json') as f:
    data = json.load(f)
skills = data.get('skills', []) if isinstance(data, dict) else data
term = '$term'.lower()
for s in skills:
    name = s.get('name','').lower()
    desc = s.get('description','').lower()
    tags = ' '.join(s.get('tags',[])).lower()
    if term in name or term in desc or term in tags:
        print(f\"  {s['name']:<30} v{s.get('version','?')}  {s.get('description','')}\")
if '$term' not in dir():
    print('  No matches found')
")
  else
    echo "  No index found. Run hub-sync.sh first."
  fi
}

if [ $# -eq 0 ]; then
  echo "Usage: bash hub-install.sh <skill-name>"
  echo "       bash hub-install.sh list"
  echo "       bash hub-install.sh search <term>"
  exit 1
fi

if [ "$1" = "list" ]; then
  show_list
  exit 0
fi

if [ "$1" = "search" ]; then
  show_search "$2"
  exit 0
fi

SKILL_NAME="$1"
SKILL_SRC="$REPO_DIR/skills/$SKILL_NAME"
SKILL_DEST="$HERMES_SKILLS/$SKILL_NAME"

if [ ! -d "$SKILL_SRC" ]; then
  echo "❌ Skill '$SKILL_NAME' not found in hub."
  echo "   Run 'bash hub-install.sh list' to see available skills."
  exit 1
fi

# Install to Hermes skills directory
mkdir -p "$HERMES_SKILLS"
cp -r "$SKILL_SRC" "$SKILL_DEST"

# Also mark as installed in hub
mkdir -p "$INSTALLED_DIR"
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$INSTALLED_DIR/$SKILL_NAME"

echo ""
echo "✅ Skill '$SKILL_NAME' installed!"
echo "   Location: $SKILL_DEST"
echo "   Available in your Hermes via skill_view(name='$SKILL_NAME')"
echo ""