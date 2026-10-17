---
title: Changelog
status: current
owner: project-maintainers
updated: 2026-10-17
---

# Changelog

[中文](CHANGELOG.md)

Translation of the Chinese primary version. Commands and historical log excerpts retain their original language where applicable.

This index collects historical release descriptions. See [version records](docs/releases/README.en.md) for publication status.

## Unreleased

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
