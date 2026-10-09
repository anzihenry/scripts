---
title: 0.3.0 version record
status: planned
owner: project-maintainers
updated: 2026-10-10
---

## v0.3.0

[中文](README.md)

Translation of the Chinese primary version. Commands and historical log excerpts retain their original language where applicable.

This version establishes stable boundaries and regression guards for CLI assembly and core flows after module splitting, consolidating the entry, expanding argument matrices, and simplifying setup/maintain/job runtimes.

### Highlights

- Stable CLI layers: entry → help → runtime → forwarding → validators → dispatch.
- Layering conventions specify placement of changes and verification requirements.
- Expanded invalid/boundary argument and help-consistency tests.
- Core workflows split into small phases with thin orchestrators.

### Included improvements

- bin/lib/help*.sh and help_router.sh
- bin/lib/validators*.sh
- bin/lib/cli_dispatch*.sh
- bin/lib/cli_forward_args.sh
- docs/engineering/cli-layering.md
- tests/cli_validators_guard.sh
- tests/job_scheduler_guard.sh
- tests/setup_runtime_guard.sh
- tests/macos_installer_flow_guard.sh
- tests/maintain_runtime_guard.sh

### Bootstrap

```bash
BOOTSTRAP_TAG="v0.3.0"
curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh
```

### Notes

Bare 0.3.0 normalizes to v0.3.0. Historical CLI regression commands were bash tests/syntax_guard.sh, bash tests/smoke_cli.sh, zsh tests/cli_dispatch_guard.sh, and zsh tests/cli_validators_guard.sh. Stable Formula targets v0.3.0; HEAD remains available for development.
