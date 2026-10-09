---
title: 0.5.0 version record
status: planned
owner: project-maintainers
updated: 2026-10-10
---

## v0.5.0

[中文](README.md)

Translation of the Chinese primary version. Commands and historical log excerpts retain their original language where applicable.

This version adds process-level pre-release E2E gates beyond CI: environment-independent sandboxes and command stubs, plus tag-triggered release.yml checks of actual macOS flows and Formula installation. It fixes two hidden set-e defects first found by E2E.

### Highlights

- tests/e2e redirects HOME/configuration/logs/LaunchAgents, records stubbed brew/launchctl/gh/git/curl calls, runs real scripts, and asserts files, call sequences, and exit codes.
- Eight flows: job create/list/disable, release verify/publish, maintain brew, setup brew configure, and bootstrap install. Run bash tests/e2e/run_all.sh.
- On v* tags, release.yml runs all guards/lint/smoke/E2E, real release verify/dry-run flows, and Formula installation on macos-latest.
- ci.yml runs E2E on every push/PR.

### Bug fixes

- Job list returned exit 1 with existing jobs: `((count++))` initially returns old value zero and triggers errexit. Use `count=$((count + 1))`.
- The Xcode CLI wait loop had the same `((wait_count++))` hazard.
- Piped bootstrap provides self-contained fallbacks when utils.sh is absent, avoiding path-resolution failures.

### Improvements

Add shims/<cmd> with recording and behavior to extend E2E. Checklists and README include E2E as a pre-release requirement.

### Included files

.github/workflows/ci.yml, .github/workflows/release.yml, tests/e2e (library, runner, eight cases, eight stubs and shared recorder), job/lib/job_launchctl.sh, lib/utils.sh, bootstrap/install.sh, README.md, docs/releases/0.4.0/validation.md.

### Bootstrap

```bash
BOOTSTRAP_TAG="v0.5.0"
curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh
```

### Notes

The development guide is authoritative. Historical release snapshot matching CI: zsh tests/syntax_guard.sh; bash tests/smoke_cli.sh; bash tests/e2e/run_all.sh; zsh tests/cli_dispatch_guard.sh; zsh tests/release_publish_guard.sh; ./lint/lint_shell.sh.
