---
title: Historical smoke-test design
status: superseded
owner: project-maintainers
updated: 2026-10-10
---

# Phase 6 smoke tests

[中文](phase-6-smoke-tests.md)

Translation of the Chinese primary version. Commands and historical log excerpts retain their original language where applicable.

> Historical record, not current status; archived in August 2026. This describes the original syntax/smoke design. Its coverage list is outdated: the later suite has 19 smoke checks, plus function guards and process-level E2E. See the [current development guide](../../../../guides/development.en.md).

## Goal

Add a directly runnable minimal regression layer for CLI help, invalid arguments, and safe dry-run paths. It requires no additional test framework and does not cover setup installation paths that modify the real environment.

## Entries

```bash
zsh tests/syntax_guard.sh
./tests/smoke_cli.sh
```

syntax_guard.sh selects zsh -n/bash -n by shebang, without ShellCheck/shfmt dependencies. smoke_cli.sh checks key success/failure paths of the unified CLI.

## Historical coverage

1. macos-scripts --help.
2. macos-scripts lint help.
3. macos-scripts maintain brew --dry-run.
4. Release verify missing-tag error.
5. Setup github rejecting --domain example.com.
6. Job list.
7. Job disable --job-name ... --dry-run.
8. Job create --job-name ... --script ... --interval ... --dry-run -- ... argument forwarding.
9. Job create --job-name ... --interval ... --dry-run missing-script error.
10. Job create --job-name ... --script ... --interval abc --dry-run invalid-interval error.
11. Job create --job-name bad name ... rejecting stray arguments before the separator.

## Design principles

Cover stable command entries without real changes. Every case overrides MACOS_SCRIPTS_LOG_DIR and MACOS_SCRIPTS_CONFIG_DIR with temporary directories. Avoid commands installing real software or modifying user configuration.

## Excluded at this phase

setup packages, setup shell, setup git, maintain installer list, and real remote release publish/verify interactions were excluded. They change environments or depend on networking, system services, or authentication and were better recorded as manual baseline checks.
