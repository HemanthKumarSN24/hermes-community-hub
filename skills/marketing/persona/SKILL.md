---
name: persona
description: "Generate data-driven user personas for UX research and product design. Usage: /persona generate [options]"
version: 1.0.0
author:
  name: "Alireza Rezvani"
  github: alirezarezvani
tags: [persona]
category: marketing
platforms: [macos, linux, windows]
license: MIT
metadata:
  hermes:
    related_skills: []
    source: "claude-skills"
    original_author: "Alireza Rezvani"
---

# /persona

Generate structured user personas with demographics, goals, pain points, and behavioral patterns.

## Usage

```
/persona generate                                            Generate persona (interactive)
/persona generate json                                       Generate persona as JSON
```

## Input Format

Interactive mode prompts for product context. Alternatively, provide context inline:

```
/persona generate
> Product: B2B project management tool
> Target: Engineering managers at mid-size companies
> Key problem: Cross-team visibility
```

## Examples

```
/persona generate
/persona generate json
/persona generate json > persona-eng-manager.json
```

## Scripts
- `product-team/skills/ux-researcher-designer/scripts/persona_generator.py` — Persona generator (positional `json` arg for JSON output)

## Skill Reference
> `product-team/skills/ux-researcher-designer/SKILL.md`