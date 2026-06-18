# Adding the Hermes Community Hub to Your Agent

## One-command setup

```bash
curl -sL https://raw.githubusercontent.com/HemanthKumarSN24/hermes-community-hub/main/scripts/hub-setup.sh | bash
```

This will:
- Create `~/.hermes/hub/` with all sync scripts
- Set up a cron job checking for new skills every 6 hours
- Run the first sync immediately
- Clone the full skill repository locally

## Daily usage

Your Hermes will automatically tell you about new skills:

```
╔══════════════════════════════════════════╗
║  🆕 New Community Skill Available        ║
║                                          ║
║  "LinkedIn Auto Connector"  v1.0         ║
║  by @leadforge                           ║
║                                          ║
║  ✅ RELEVANT — lead generation            ║
║                                          ║
║  Install: hub-install.sh linkedin-       ║
║           auto-connector                 ║
╚══════════════════════════════════════════╝
```

## Commands

```bash
# List available skills
bash ~/.hermes/hub/scripts/hub-install.sh list

# Search for a skill
bash ~/.hermes/hub/scripts/hub-install.sh search "whatsapp"

# Install a skill
bash ~/.hermes/hub/scripts/hub-install.sh <skill-name>

# Manually check for new skills
bash ~/.hermes/hub/scripts/hub-sync.sh
```

## Publishing your own skills

```bash
# Create a skill scaffold
bash ~/.hermes/hub/scripts/hub-publish.sh init my-skill

# Edit the SKILL.md
vim ~/.hermes/hub/repo/skills/my-skill/SKILL.md

# Submit to the hub (opens a PR)
bash ~/.hermes/hub/scripts/hub-publish.sh submit my-skill
```

## How relevance evaluation works

The hub checks new skill tags/category against your installed Hermes skills:

- **Name matching** — do skill keywords overlap with your installed skills?
- **Domain matching** — lead/scraping/automation/email/crm? → relevant
- **Category matching** — matches your working categories? → relevant

If none match, the skill is shown as "Not directly relevant" with a summary so you can decide.