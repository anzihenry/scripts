---
title: Architecture and modules
status: current
owner: project-maintainers
updated: 2026-10-17
---

# Architecture and modules

[中文](architecture.md)

Translation of the Chinese primary version. Commands and historical log excerpts retain their original language where applicable.

The target environment is macOS 14+, system Zsh.

## Current modules

- `bin/lib/`: CLI help, validation, dispatch, argument forwarding, and shared runtime.
- `setup/lib/`: setup runtime, configuration writes, language environments, and post-install checks.
- `maintain/lib/`: argument parsing and workflow orchestration for Homebrew updates and installer/USB creation.
- `lib/utils.sh`: log path resolution, runtime helpers, and dependency checks.
- `tests/`: syntax checks, smoke tests, function guards, and sandbox E2E tests.

`bin/macos-scripts` initializes log/configuration paths and assembles the CLI. Business executors perform system operations. Shared logging and dependency checks live in `lib/`; Homebrew installation helpers live in `setup/lib/`.

[CLI layering rules](cli-layering.en.md), [development validation](../guides/development.en.md).

## Reusable components

`packages/zsh-kit/lib` owns logging, execution, stages, resource locks and atomic configuration writers. Root `lib/` retains application defaults and compatibility adapters. Homebrew and installation policies remain in the application. See [component contracts](../../packages/zsh-kit/README.md) and the [implementation plan](reuse-plan.md).
