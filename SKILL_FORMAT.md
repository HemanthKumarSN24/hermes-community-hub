# Skill Format Specification

Every skill in the Hermes Community Hub follows this structure:

## Directory Structure

```
skills/<skill-name>/
├── SKILL.md              # Required — the skill itself
├── references/           # Optional — supporting docs
│   └── *.md
├── templates/            # Optional — starter files
│   └── *
└── scripts/              # Optional — runnable actions
    └── *.sh / *.py
```

## SKILL.md Frontmatter

```yaml
---
name: skill-name
description: "One-line description (max 120 chars)"
version: 1.0.0
author: 
  name: "Your Name or Org"
  github: "your-github-handle"     # optional
tags: [tag1, tag2, tag3]
category: automation               # one of the categories below
platforms: [macos, linux]          # macos, linux, windows
published: 2026-06-18
license: MIT
metadata:
  hermes:
    related_skills: [other-skill-1]
    icon: 🛠️                        # single emoji
    readme_url: ""                   # optional link to full docs
---
```

## Body Format

The body (after `---`) is standard markdown. Good skills have:

1. **Overview** — what this skill does, when to use it
2. **Prerequisites** — any installs, env vars, or setup needed
3. **Step-by-step** — numbered steps with exact commands
4. **Pitfalls** — common mistakes
5. **Verification** — how to confirm it works

## Categories

| Category | Description |
|---|---|
| automation | Workflow automation, scheduling, CI/CD |
| devops | Docker, deployment, infra management |
| data-science | Data analysis, ML, visualization |
| web | Web scraping, browser automation |
| creative | Design, art, video, music |
| productivity | Note-taking, email, calendars |
| business | Lead gen, CRM, marketing |
| gaming | Game servers, bots, mods |
| communication | Email, messaging, social media |
| research | Academic research, paper discovery |
| social-media | Social platforms, posting, analytics |
| mlops | Model serving, training, evaluation |
| custom | Anything else |

## Validation Rules

- `name` must be lowercase, hyphens only, max 64 chars
- `description` max 120 chars, single line
- `version` must be semver
- `tags` max 8 tags
- `category` must be one of the listed categories
- `platforms` must be an array with at least one entry