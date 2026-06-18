---
name: dbt-transformation-patterns
description: "Production-ready patterns for dbt (data build tool) including model organization, testing strategies, documentation, and incremental processing."
version: 1.0.0
author:
  name: "sickn33 / Antigravity Community"
  github: sickn33
tags: [dbt, transformation, patterns, data]
category: data
platforms: [macos, linux, windows]
license: MIT
metadata:
  hermes:
    source: "antigravity-awesome-skills"
    risk: "none"
    date_added: "2026-02-27"
    original_author: "Antigravity Community"
---

# dbt Transformation Patterns

Production-ready patterns for dbt (data build tool) including model organization, testing strategies, documentation, and incremental processing.

## Use this skill when

- Building data transformation pipelines with dbt
- Organizing models into staging, intermediate, and marts layers
- Implementing data quality tests and documentation
- Creating incremental models for large datasets
- Setting up dbt project structure and conventions

## Do not use this skill when

- The project is not using dbt or a warehouse-backed workflow
- You only need ad-hoc SQL queries
- There is no access to source data or schemas

## Instructions

- Define model layers, naming, and ownership.
- Implement tests, documentation, and freshness checks.
- Choose materializations and incremental strategies.
- Optimize runs with selectors and CI workflows.
- If detailed patterns are required, open `resources/implementation-playbook.md`.

## Resources

- `resources/implementation-playbook.md` for detailed dbt patterns and examples.

## Limitations
- Use this skill only when the task clearly matches the scope described above.
- Do not treat the output as a substitute for environment-specific validation, testing, or expert review.
- Stop and ask for clarification if required inputs, permissions, safety boundaries, or success criteria are missing.