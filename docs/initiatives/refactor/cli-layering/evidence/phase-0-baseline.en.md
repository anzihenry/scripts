---
title: Historical baseline record
status: superseded
owner: project-maintainers
updated: 2026-10-10
---

# Phase 0 baseline

[中文](phase-0-baseline.md)

Translation of the Chinese primary version. Commands and historical log excerpts retain their original language where applicable.

> Historical record, not current status; archived in August 2026. This captures the initial refactoring baseline on 2026-04-25, version v0.2.0 and 17 Shell files. Use the [current development guide](../../../../guides/development.en.md) for present checks.

## Goal

Freeze key entries, verification commands, environment constraints, and known differences before incremental refactoring, providing a reference for subsequent phases.

## Scope

CLI: bin/macos-scripts. Setup: homebrew-setup.sh and macos-setup.sh. Maintenance: formulaes_casks_updater.sh and macos_sys_usb_maker.sh. Lint: lint/lint_shell.sh.

## Baseline commands

```bash
./lint/lint_shell.sh
zsh bin/macos-scripts --help
zsh bin/macos-scripts setup brew configure --dry-run
zsh bin/macos-scripts maintain brew --dry-run
zsh bin/macos-scripts maintain installer list
```

## Recorded results: 2026-04-25

### 1. CLI help

```bash
zsh bin/macos-scripts --help
```

Top-level help printed successfully; the reported version was v0.2.0.

### 2. Setup brew configure dry-run

```bash
zsh bin/macos-scripts setup brew configure --dry-run
```

Failed in the Codex sandbox because the network precheck reported a USTC mirror connection failure. Writing ~/Library/Logs/macos-scripts/homebrew-setup.log was also blocked. This does not by itself establish a functional regression; subsequent checks must distinguish logic changes from network/sandbox limits.

### 3. Maintain brew dry-run

```bash
zsh bin/macos-scripts maintain brew --dry-run
```

The preview completed successfully. Brew update, upgrade, and cleanup used preview branches. Seven outdated Casks were detected, all matching the default exclusion list.

### 4. Installer list

```bash
zsh bin/macos-scripts maintain installer list
```

The sandbox invocation did not return reliably after entering softwareupdate --list-full-installers. Writing ~/Library/Logs/macos-scripts/macos-installer.log was also blocked. Recheck in a real local terminal; Phase 0 records this as environment-dependent rather than passed.

### 5. Lint

```bash
zsh lint/lint_shell.sh
```

Passed for 17 Shell files. Zsh received syntax checks; Bash/sh received syntax, ShellCheck, and shfmt. The lint entry initially lacked executable permission, preventing direct ./lint/lint_shell.sh invocation.

## Constraints and known differences

1. Maintenance instructions expected Bash 3.x, while the two main maintenance executors used Zsh. Choose a clear target before further refactoring: standardize on Zsh or gradually move back to Bash.
2. Default logs depend on writable user directories and can be denied by sandboxes. Retain defaults but allow environment overrides during verification.
3. Zsh static coverage was limited to syntax checks, without ShellCheck/shfmt. Track improvement as later work rather than introducing extensive formatting changes in Phase 0.

## Deliverables and completion criteria

Deliverables: this baseline, the command set, and executable permission for the lint entry. Completion requires reusable minimal checks, explicit environment-dependent findings and instruction/implementation differences, without changing existing workflows or CLI semantics.
