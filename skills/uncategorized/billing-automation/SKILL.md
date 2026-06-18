---
name: billing-automation
description: "Master automated billing systems including recurring billing, invoice generation, dunning management, proration, and tax calculation."
version: 1.0.0
author:
  name: "sickn33 / Antigravity Community"
  github: sickn33
tags: [billing, automation]
category: uncategorized
platforms: [macos, linux, windows]
license: MIT
metadata:
  hermes:
    source: "antigravity-awesome-skills"
    risk: "safe"
    date_added: "2026-02-27"
    original_author: "Antigravity Community"
---

# Billing Automation

Master automated billing systems including recurring billing, invoice generation, dunning management, proration, and tax calculation.

## Use this skill when

- Implementing SaaS subscription billing
- Automating invoice generation and delivery
- Managing failed payment recovery (dunning)
- Calculating prorated charges for plan changes
- Handling sales tax, VAT, and GST
- Processing usage-based billing
- Managing billing cycles and renewals

## Do not use this skill when

- You only need a one-off invoice or manual billing
- The task is unrelated to billing or subscriptions
- You cannot change pricing, plans, or billing flows

## Instructions

- Define plans, pricing, billing intervals, and proration rules.
- Map subscription lifecycle states and renewal/cancellation behavior.
- Implement invoicing, payments, retries, and dunning workflows.
- Model taxes and compliance requirements per region.
- Validate with sandbox payments and reconcile ledger outputs.
- If detailed templates are required, open `resources/implementation-playbook.md`.

## Safety

- Do not charge real customers in testing environments.
- Verify tax handling and compliance obligations before production rollout.

## Resources

- `resources/implementation-playbook.md` for detailed patterns, checklists, and examples.

## Limitations
- Use this skill only when the task clearly matches the scope described above.
- Do not treat the output as a substitute for environment-specific validation, testing, or expert review.
- Stop and ask for clarification if required inputs, permissions, safety boundaries, or success criteria are missing.