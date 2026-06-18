---
name: conductor-validator
description: "'Validates Conductor project artifacts for completeness,"
version: 1.0.0
author:
  name: "sickn33 / Antigravity Community"
  github: sickn33
tags: [conductor, validator, workflow]
category: workflow
platforms: [macos, linux, windows]
license: MIT
metadata:
  hermes:
    source: "antigravity-awesome-skills"
    risk: "safe"
    date_added: "2026-02-27"
    original_author: "Antigravity Community"
---

# Check if conductor directory exists
ls -la conductor/

# Find all track directories
ls -la conductor/tracks/

# Check for required files
ls conductor/index.md conductor/product.md conductor/tech-stack.md conductor/workflow.md conductor/tracks.md
```

## Use this skill when

- Working on check if conductor directory exists tasks or workflows
- Needing guidance, best practices, or checklists for check if conductor directory exists

## Do not use this skill when

- The task is unrelated to check if conductor directory exists
- You need a different domain or tool outside this scope

## Instructions

- Clarify goals, constraints, and required inputs.
- Apply relevant best practices and validate outcomes.
- Provide actionable steps and verification.
- If detailed examples are required, open `resources/implementation-playbook.md`.

## Pattern Matching

**Status markers in tracks.md:**

```
- [ ] Track Name  # Not started
- [~] Track Name  # In progress
- [x] Track Name  # Complete
```

**Task markers in plan.md:**

```
- [ ] Task description  # Pending
- [~] Task description  # In progress
- [x] Task description  # Complete
```

**Track ID pattern:**

```
<type>_<name>_<YYYYMMDD>
Example: feature_user_auth_20250115
```

## Limitations
- Use this skill only when the task clearly matches the scope described above.
- Do not treat the output as a substitute for environment-specific validation, testing, or expert review.
- Stop and ask for clarification if required inputs, permissions, safety boundaries, or success criteria are missing.