---
title: 0.3.0 release and validation record
status: planned
owner: project-maintainers
updated: 2026-10-10
---

# v0.3.0 release checklist

[中文](validation.md)

Translation of the Chinese primary version. Commands and historical log excerpts retain their original language where applicable.

> Migrated historical material. Official publication status/time and candidate commit remain unverified. A checklist is not acceptance evidence. See the [current releasing guide](../../guides/releasing.en.md).

## Release goal

Version 0.3.0, tag v0.3.0, branch main. Scope matches the [version description](README.en.md).

## Before release

Review the worktree and exclude temporary changes. Align CLI and bootstrap version defaults with v0.3.0; ensure README/bootstrap/release examples and notes match. For 0.1.0, verify Formula caveats and stable URL/checksum refer to the release archive.

## Historical command sequence

Commands below reproduce the Chinese checklist's historical examples. Run from the repository root only in the corresponding release context; use the current guide for new releases. Commands select Chinese notes by default; an English publication can explicitly select README.en.md.

### Pre-release checks

```bash
./bin/macos-scripts --version
./bin/macos-scripts release verify 0.3.0 || true
bash tests/syntax_guard.sh
bash tests/smoke_cli.sh
zsh tests/cli_dispatch_guard.sh
zsh tests/cli_validators_guard.sh
zsh tests/setup_runtime_guard.sh
zsh tests/macos_installer_flow_guard.sh
zsh tests/maintain_runtime_guard.sh
zsh tests/job_scheduler_guard.sh
```

### Commit and tag

```bash
git checkout main
git pull --ff-only origin main
git add bin/macos-scripts bootstrap/install.sh README.md maintain/github_release_publish.sh docs/releases/0.3.0/README.md docs/releases/0.3.0/validation.md
git commit -m "Prepare release v0.3.0"
git push origin main
git tag -a v0.3.0 -m "Release v0.3.0"
git push origin v0.3.0
```

### Verify remote release state

```bash
git ls-remote --tags origin | grep "refs/tags/v0.3.0$"
curl -I https://raw.githubusercontent.com/anzihenry/scripts/v0.3.0/bootstrap/install.sh
./bin/macos-scripts release verify v0.3.0
```

### Publish

```bash
./bin/macos-scripts release publish v0.3.0 --yes
```

### Equivalent underlying command

```bash
bash maintain/github_release_publish.sh \
  --tag v0.3.0 \
  --notes-file docs/releases/0.3.0/README.md \
  --update-existing \
  --yes
```

### Compute archive checksum

```bash
curl -L https://github.com/anzihenry/scripts/archive/refs/tags/v0.3.0.tar.gz -o /tmp/macos-scripts-v0.3.0.tar.gz
shasum -a 256 /tmp/macos-scripts-v0.3.0.tar.gz
```

## Acceptance expectations

The version output must be macos-scripts v0.3.0; bootstrap URL/tag/flow and public wording must match. Required syntax, lint, smoke, and applicable guards must pass.



## Tag and publication

Create/push the annotated tag only when main contains the intended release commit. The remote must contain refs/tags/v0.3.0, and the raw bootstrap URL must return 200 OK. Publish a normal Release targeting main, titled v0.3.0; use the CLI when UI tools are unreliable. Verify-only checks state without publishing.

## Stable Formula checksum

Compute SHA-256 from the remote tag archive after tagging, then update the Formula URL/checksum and push a follow-up main commit.

## After release

Check piped bootstrap dry-run, real tap installation, and release body agreement with [notes](README.en.md). After Formula checksum updates, recheck that stable installation targets v0.3.0.
