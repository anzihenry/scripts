---
title: Backlog triage template
status: current
owner: project-maintainers
updated: 2026-10-17
---

# Backlog triage template

[中文](backlog-triage.md)

Translation of the Chinese primary version. Commands and historical log excerpts retain their original language where applicable.

Map proposed requirements, refactors, and fixes to three project goals before choosing priorities and acceptance criteria.

## Three goals

1. Environment management: setup, setup/lib, brew.conf.sh, system maintenance scripts, lib/colors.sh, and lib/utils.sh. Does the work improve the main initialization/configuration/maintenance path, idempotency, safety, or repeatability?
2. Unified CLI: bin/macos-scripts and bin/lib. Does it strengthen the unified entry, help, validation, or subcommand consistency?
3. Self-validation: tests, lint/lint_shell.sh, docs/engineering, README, AGENTS, and GitHub instructions. Does it improve evidence that changes preserve behavior through syntax/smoke/lint checks, verification documentation, or collaboration rules?

## Priorities

- P0: broken main path or clear risk. Examples: the CLI cannot perform its primary function; setup behaves incorrectly; dry-run/validation/log protection fails; tests show a real regression; documentation contradicts behavior.
- P1: valuable structural consolidation. Split large scripts, consolidate repeated high-risk logic, reduce modification cost, or make entries true orchestrators.
- P2: stronger regression coverage. Main-path smoke, high-risk failure guards, syntax/verification for frequently changed modules, and executable documented checks.
- P3: experience and consistency. Clearer copy, consistent names, complete examples, uniform output.
- P4: local polish with limited return. Formatting, cosmetic renaming, or restructuring that adds neither capability nor verification.

## Template

```md
### <Task title>

- Goal: environment management / unified CLI / self-validation
- Priority: P0 / P1 / P2 / P3 / P4
- Type: bug fix / structural refactor / regression coverage / documentation alignment

- Background:
  Explain why this work is needed now.

- Affected modules:
  List the files or directories.

- Rationale:
  - What problem does it solve?
  - Why does it serve this goal?
  - Why does it deserve this priority?

- One commit:
  Define the smallest reviewable result.

- Acceptance:
  Specify checks, including at least one reproducible verification.
```

## Quick triage

Ask: which goal does it serve; does it affect the main path; does it reduce future maintenance cost; can it include a concrete verification?

Prioritize main-path work with verification and low-risk structural consolidation. Deprioritize purely cosmetic changes.

## Default ordering

1. Main paths: setup and CLI entry consistency.
2. Regression coverage: broader smoke, failure guards, and aligned verification entry points.
3. Remaining structural work: maintain scripts, high-risk configuration writes, and shared helpers.
4. Experience: copy, examples, and small directory cleanups.

Use the template before adding work to the backlog. Lower the priority of tasks unrelated to the three goals. Tasks without a concrete verification command are not ready for immediate execution.
