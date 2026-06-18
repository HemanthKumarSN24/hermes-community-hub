---
name: pipeline
description: "Detect stack and generate CI/CD pipeline configs. Usage: /pipeline <detect|generate> [options]"
version: 1.0.0
author:
  name: "Alireza Rezvani"
  github: alirezarezvani
tags: [pipeline]
category: productivity
platforms: [macos, linux, windows]
license: MIT
metadata:
  hermes:
    related_skills: []
    source: "claude-skills"
    original_author: "Alireza Rezvani"
    argument_hint: "<detect|generate> [options]"
---

# /pipeline

Detect project stack and generate CI/CD pipeline configurations for GitHub Actions or GitLab CI.

## Usage

```
/pipeline detect [--repo <project-dir>]               Detect stack, tools, and services
/pipeline generate --platform github|gitlab [--repo <project-dir>]  Generate pipeline YAML
```

## Examples

```
/pipeline detect --repo ./my-project
/pipeline generate --platform github --repo .
/pipeline generate --platform gitlab --repo .
```

## Scripts
- `engineering/skills/ci-cd-pipeline-builder/scripts/stack_detector.py` — Detect stack and tooling (`--repo <path>`, `--format text|json`)
- `engineering/skills/ci-cd-pipeline-builder/scripts/pipeline_generator.py` — Generate pipeline YAML (`--platform github|gitlab`, `--repo <path>`, `--input <stack.json>`, `--output <file>`)

## Skill Reference
→ `engineering/skills/ci-cd-pipeline-builder/SKILL.md`