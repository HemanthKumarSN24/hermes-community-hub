#!/bin/bash
# ==============================
# Hermes Community Hub - Publish
# ==============================
# Submit a skill to the hub via GitHub PR
#
# Usage:
#   bash hub-publish.sh init <skill-name>     # Create skill scaffold
#   bash hub-publish.sh submit <skill-name>    # Submit to hub (opens PR)
#
# Prerequisites: gh CLI logged in

set -e

HUB_DIR="$HOME/.hermes/hub"
REPO_DIR="$HUB_DIR/repo"
HUB_REPO="hermeshub/hermes-community-hub"

if [ $# -lt 2 ]; then
  echo "Usage:"
  echo "  bash hub-publish.sh init <skill-name>     # Create a new skill"
  echo "  bash hub-publish.sh submit <skill-name>   # Submit to hub"
  echo ""
  echo "Examples:"
  echo "  bash hub-publish.sh init my-awesome-skill"
  exit 1
fi

ACTION="$1"
SKILL_NAME="$2"
SKILL_DIR="$REPO_DIR/skills/$SKILL_NAME"

if [ "$ACTION" = "init" ]; then
  if [ -d "$SKILL_DIR" ]; then
    echo "❌ Skill '$SKILL_NAME' already exists at $SKILL_DIR"
    exit 1
  fi
  
  mkdir -p "$SKILL_DIR/references" "$SKILL_DIR/templates" "$SKILL_DIR/scripts"
  
  # Create scaffold SKILL.md
  cat > "$SKILL_DIR/SKILL.md" << 'EOF'
---
name: SKILL_NAME
description: "One-line description (max 120 chars)"
version: 1.0.0
author:
  name: "Your Name"
tags: [tag1, tag2]
category: automation
platforms: [macos, linux]
published: 2026-06-18
license: MIT
metadata:
  hermes:
    related_skills: []
    icon: 🛠️
---

## Overview

Describe what this skill does and when to use it.

## Prerequisites

- List any required tools, accounts, or setup

## Step-by-step

1. First step with exact command
2. Second step
3. Third step

## Pitfalls

- Common mistakes to avoid

## Verification

How to confirm the skill works
EOF

  # Replace placeholder
  sed -i '' "s/SKILL_NAME/$SKILL_NAME/g" "$SKILL_DIR/SKILL.md"
  
  echo ""
  echo "✅ Scaffold created: $SKILL_DIR"
  echo ""
  echo "Next steps:"
  echo "  1. Edit $SKILL_DIR/SKILL.md"
  echo "  2. Add supporting files to references/, templates/, scripts/"
  echo "  3. Run: bash hub-publish.sh submit $SKILL_NAME"
  echo ""

elif [ "$ACTION" = "submit" ]; then
  if [ ! -f "$SKILL_DIR/SKILL.md" ]; then
    echo "❌ No SKILL.md found at $SKILL_DIR"
    echo "   Run 'hub-publish.sh init $SKILL_NAME' first"
    exit 1
  fi
  
  # Branch and commit
  BRANCH="skill/$SKILL_NAME"
  cd "$REPO_DIR"
  
  git checkout main 2>/dev/null || true
  git pull --ff-only 2>/dev/null || true
  git checkout -b "$BRANCH"
  git add "skills/$SKILL_NAME/"
  git commit -m "Add skill: $SKILL_NAME"
  git push origin "$BRANCH"
  
  # Open PR
  echo "Opening pull request..."
  gh pr create \
    --repo "$HUB_REPO" \
    --title "Add skill: $SKILL_NAME" \
    --body "## New Skill: $SKILL_NAME

This PR adds a new skill to the Hermes Community Hub.

**Author:** $(whoami)
**Description:** $(head -5 "$SKILL_DIR/SKILL.md" | grep 'description:' | sed 's/.*: //')

---

*Submitted via hub-publish.sh*" \
    --base main \
    --head "$BRANCH"
  
  echo ""
  echo "✅ Submitted! PR opened at:"
  gh pr view --repo "$HUB_REPO" --json url -q .url 2>/dev/null || echo "  https://github.com/$HUB_REPO/pulls"
  echo ""
else
  echo "Unknown action: $ACTION"
  echo "Use: init or submit"
  exit 1
fi