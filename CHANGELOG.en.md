---
title: Changelog
status: current
owner: project-maintainers
updated: 2026-10-21
---

# Changelog

[中文](CHANGELOG.md)

Translation of the Chinese primary version. Commands and historical log excerpts retain their original language where applicable.

This index collects historical release descriptions. See [version records](docs/releases/README.en.md) for publication status.

## Unreleased

- Make repeated runs converge: atomic in-place config blocks, preserved shell settings/repos, staged validated downloads, reusable domain-specific SSH identities and paginated key queries, no implicit language upgrades, merged pip settings and unique PATH. Skip unchanged Homebrew config transactions and fail on incomplete package/detection results. Validate installer payload OS versions/integrity and device-locked UUID/digest USB completion records; skip matching Release content. Add an idempotence guard to CI/release checks.

- Audit fixes: use a waitable logger and drain it before exit without replacing business exit codes; reject log symlinks before opening; preserve release options before the tag and custom tap URLs in fresh-machine previews; clarify Formula-selected stable versions and distinguish unreleased source from v0.5.0 examples.

- Make help and CLI version queries side-effect free: skip directories, logging, rotation, locks, and environment checks, even with unusable log paths. Parse bootstrap and executor arguments before logging, and reject extra version-query arguments.

- Reject root bootstrap runs, including sudo and dry-run, before creating logs, configuration directories, or locks. Root can still display help without writes and receives guidance to retry as a regular user.

- Validate arm64/x86_64 execution architecture before bootstrap installation; recommend a native terminal under Rosetta while preserving existing Homebrew discovery without automatic migration or reinstallation. Help skips the check; dry-run performs it.

- Require macOS 14+ consistently across bootstrap, setup, maintenance, release, and lint execution; stop before external operations on unsupported or unreadable versions while keeping help and CLI version queries available.

- Add private backups, failure/interruption rollback, and locking for default USTC configuration; delete the current backup on success and retain it on failure. Verify connectivity without resetting repositories or forcing a core clone.
- Bootstrap skips installation and upgrades when macos-scripts is already installed, then continues configuration; dry-run follows the same behavior.
- Read bootstrap confirmation from /dev/tty for both entry points; fail with --yes guidance when no terminal is available, while dry-run skips confirmation.
- Limit official and USTC Homebrew installer script downloads to 10 seconds for connection and 120 seconds total, preserving brew rechecks and automatic fallback on timeout.
- Validate the CLI with macos-scripts --version after installing or skipping an existing installation; stop with repair guidance on failure, and only preview the check in dry-run.
- Probe Homebrew through PATH, the default ARM location, and the default Intel location in order, deduplicating candidates and skipping broken entries; use the selected absolute path for subsequent operations.
- Lock the entire bootstrap run to prevent concurrent installation; release on completion, failure, or catchable interruption, while help and dry-run remain lock-free.
- Add a single bootstrap failure summary with stage, exit code, log location, and recovery guidance while retaining original errors; distinguish cancellation and signal interruption.
- Use ~/Library/Logs/macos-scripts for all entry points, retaining MACOS_SCRIPTS_LOG_DIR overrides and removing script-directory fallbacks; summarize actual paths, version, configuration state, and log location after successful bootstrap.
- Append per-run log separators with start time, script name, execution mode, and PID without recording full arguments; maintenance error logs add the header on the first failure of a run.
- Rotate logs during writing (defaults: 5 MiB and five archives), prune archives older than 30 days on use, and support environment overrides with kernel locking for concurrent writers; remove four legacy repository logs.
- Remove default --force from bootstrap GitHub setup guidance and usage examples, keeping the option available for explicit use.
- Validate xcrun --find clang for existing CLT paths and newly installed tools; stop for repair when an existing toolchain is broken and wait for both path and compiler readiness during installation, consistently across entry points.

- Retain automatic official-to-USTC fallback with a brew usability recheck; propagate non-interactive mode to both installers for `--yes`, and report download, empty-script, and installation failures.

- Unify CLT installation and waiting in local and piped bootstrap; stop on launch failure/timeout, preserve dry-run without installation or waiting, and test both execution modes.

- Remove launchd scheduling, the `job` CLI, implementation, dedicated tests, and user guides. Existing user jobs and logs are not removed.

- Standardize repository scripts, libraries, tests, and CI on system Zsh; adapt interactive input, arrays, special parameters, and exit cleanup.
- Enforce `#!/bin/zsh` and syntax checks without ShellCheck/shfmt; retain `lint fix` as a check-only compatibility entry point.
- Add Zsh migration regression tests. Upstream Homebrew installers still use Bash as required by upstream.

## 0.5.0

[Contents](docs/releases/0.5.0/README.en.md), [validation and release checklist](docs/releases/0.5.0/validation.en.md).

## 0.4.0

[Contents](docs/releases/0.4.0/README.en.md), [validation and release checklist](docs/releases/0.4.0/validation.en.md).

## 0.3.0

[Contents](docs/releases/0.3.0/README.en.md), [validation and release checklist](docs/releases/0.3.0/validation.en.md).

## 0.2.0

[Contents](docs/releases/0.2.0/README.en.md), [validation and release checklist](docs/releases/0.2.0/validation.en.md).

## 0.1.0

[Contents](docs/releases/0.1.0/README.en.md), [validation and release checklist](docs/releases/0.1.0/validation.en.md).
