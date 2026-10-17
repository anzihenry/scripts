---
title: CLI layering conventions
status: current
owner: project-maintainers
updated: 2026-10-17
---

# CLI layering conventions

[中文](cli-layering.md)

Translation of the Chinese primary version. Commands and historical log excerpts retain their original language where applicable.

## Goal and scope

Keep `bin/macos-scripts` and `bin/lib/` consistently layered so entry initialization, validation, forwarding, and business dispatch remain separate. These conventions cover CLI assembly, not business-script internals in setup, maintain, or job.

## Assembly order

1. Entry: `bin/macos-scripts`.
2. Help: `bin/lib/help*.sh`.
3. Shared runtime: `bin/lib/cli_runtime.sh`.
4. Argument forwarding: `bin/lib/cli_forward_args.sh`.
5. Validators: `bin/lib/validators*.sh`.
6. Dispatch: `bin/lib/cli_dispatch*.sh`.

## Entry layer

The entry initializes the environment, exports repository/log/configuration paths, sources modules in a fixed order, and calls `main "$@"`. It does not implement command branches, validation, help text, or forwarding. Keep it readable at a glance; typical changes concern source order or environment initialization.

## Help layer

Files: `help.sh`, `help_router.sh`, `help_main.sh`, `help_setup.sh`, `help_maintain.sh`, `help_release.sh`, `help_job.sh`, and `help_lint.sh`, all under `bin/lib/`.

Maintain help text by domain and route `help <topic>`. The router contains routing rather than text. Dispatch calls the appropriate help function for `--help` instead of assembling text. Help must not validate arguments, execute commands, or inspect business-script state.

## Shared runtime

`cli_runtime.sh` provides script runners such as `run_zsh_script` (all internal scripts use Zsh), assembly helpers such as `dispatch_validated_action`, error helpers such as `usage_error` and `command_error`, and general utilities such as `has_help_flag`.

Only cross-domain helpers with little or no domain knowledge belong here. Do not add setup/release/job-specific forwarding, large business branches, or one-off domain wrappers. A helper used in one domain belongs in its dispatch or domain helper. Knowledge of specific help text, tags, or defaults usually signals a domain-specific function.

## Argument forwarding

`cli_forward_args.sh` fills and assembles arguments passed from the CLI to underlying scripts. Examples: `setup github` adds `--domain github.com --type personal`; release publish/verify supplies normalized tags, default notes, and mode flags.

Keep forwarding here rather than in dispatch. Expose assembly-friendly `load_*_forwarded_args` interfaces. Do not execute scripts, validate arguments, or print help.

## Validation layer

Files: `validators.sh`, `validators_setup.sh`, `validators_maintain.sh`, `validators_job.sh`, and `validators_release.sh`, under `bin/lib/`.

Check argument legality and use `usage_error` for consistent errors/help. Split by domain and keep acceptance checks separate from default argument assembly. Validators must not invoke script runners, route commands, or fill forwarded defaults. Missing values, bounds, and allowed flags belong here.

## Dispatch layer

Files: `cli_dispatch.sh`, `cli_dispatch_setup.sh`, `cli_dispatch_maintain.sh`, `cli_dispatch_release.sh`, `cli_dispatch_job.sh`, and `cli_dispatch_lint.sh`, under `bin/lib/`.

Route commands and orchestrate `help -> validate -> forward -> run`. The main dispatch routes top-level commands; each domain maintains its own assembly boundary.

Local helpers are acceptable when reused within that domain and clearly reduce repetition, such as parameter-free setup dispatch. Keep validation and forwarding in their own layers and avoid complex business conditions. Branches substantially larger than the assembly sequence should be moved down.

## Naming

- `handle_*`: command/subcommand dispatch entry.
- `validate_*`: argument validation.
- `load_*_forwarded_args`: forwarding interface used by dispatch.
- `build_*_forwarded_args`: lower-level complete argument construction.
- `dispatch_*`: local orchestration helper.
- `run_*`: script execution or shared runner.

Avoid mixing build/make/collect/prepare for the same responsibility without a clear distinction, or naming domain dispatch helpers as if they were generic runtime helpers.

## Where changes belong

Choose help files for help text/routing; validators for legality checks; forwarding for argument completion; runtime for shared execution/error utilities; dispatch for command orchestration. Split changes crossing layers into small commits, separating structural changes from behavior changes.

## Regression requirements

The [development guide](../guides/development.en.md) is authoritative. CLI changes cover syntax, smoke, dispatch, and validator guards. Changes inside release, setup, job, or maintain assembly also require the corresponding guards.

## When to stop abstracting

Prefer documentation or tests when a helper saves only two or three lines while adding navigation cost, combines special cases across domains, dispatch is already a thin orchestrator, or another abstraction does not improve readability/testability. The goal is stable, readable, testable CLI layering that supports further development.
