---
title: 0.4.0 version record
status: planned
owner: project-maintainers
updated: 2026-10-10
---

## v0.4.0

[中文](README.md)

Translation of the Chinese primary version. Commands and historical log excerpts retain their original language where applicable.

This version moves quality checks from local verification to CI gates, one version source, and real-write integration tests. It fixes invalid job plists, ineffective Zsh installer locks, and empty Cask tokens on clean runners.

### Highlights

- Actions CI runs syntax, lint, smoke, and all guards on pushes/PRs.
- VERSION drives CLI/bootstrap/Formula; release verify/publish checks consistency.
- Real filesystem tests cover plist/plutil, brew error logs, installer lock directories, and volume detection.
- Lint reaches zero findings by handling SC2034 false positives for shared variables.

### Bug fixes

- Literal `\n` made job plists invalid: use `$'\n'` and restore newlines stripped by command substitution.
- Function-local EXIT traps released installer locks early in Zsh: cleanup moves to a global entry-script trap.
- Blank brew outdated lines created empty Cask names: awk NF filtering plus empty-item guards.
- Syntax guard silently relied on unavailable rg: use find.
- SSH public-key upload tokens appeared in process listings: use a temporary config and python3 JSON escaping.

### Improvements

- config_writer.sh absorbs update_shell_config; redundant setup_shell_config.sh removed.
- resolve_homebrew_bin consolidated in lib/utils.sh.
- MACOS_SCRIPTS_LAUNCH_AGENTS_DIR enables isolation.
- Gitignore adds macOS noise, editor backups, and caches.
- Tests read version assertions from VERSION.

### Included files

.github/workflows/ci.yml, VERSION, job/lib/job_plist.sh, maintain/lib/macos_installer_flow.sh, maintain/lib/brew_updater_casks.sh, maintain/lib/release_publish_{args,context}.sh, setup/lib/config_writer.sh, setup/git_forge_ssh_setup.sh, tests/job_plist_guard.sh, tests/macos_installer_flow_guard.sh, tests/maintain_runtime_guard.sh, tests/syntax_guard.sh, and tests/cli_validators_guard.sh.

### Bootstrap

```bash
BOOTSTRAP_TAG="v0.4.0"
curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh
```

### Notes

Historical CI checks: zsh tests/syntax_guard.sh; bash tests/smoke_cli.sh; zsh tests/job_plist_guard.sh; zsh tests/maintain_runtime_guard.sh; ./lint/lint_shell.sh. Stable Formula targets v0.4.0; HEAD remains available for development.
