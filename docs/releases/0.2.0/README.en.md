---
title: 0.2.0 version record
status: planned
owner: project-maintainers
updated: 2026-10-10
---

## v0.2.0

[中文](README.md)

Translation of the Chinese primary version. Commands and historical log excerpts retain their original language where applicable.

This version advances the CLI from installable scripts to release automation, verification, and clearer responsibilities, focusing on the Homebrew installation/configuration path.

### Highlights

- release publish/verify and maintain/github_release_publish.sh use gh for noninteractive Release creation/update.
- setup/homebrew-setup.sh only configures/repairs existing Homebrew; first installation belongs to bootstrap/install.sh.
- setup brew configure has a real dry-run for checks without changes.
- setup/lib/homebrew_config.sh shares shellenv, mirrors, repository synchronization, and dry-run logic.
- Stable Formula, bootstrap text, and README align with tagged releases.

### Included improvements

- `macos-scripts release verify <tag>`
- `macos-scripts release publish <tag>`
- `macos-scripts setup brew configure --dry-run`
- `bootstrap/install.sh --dry-run --yes --skip-configure`
- Installed-mode log/configuration conventions.
- Clearer bootstrap/configure responsibilities.

### Bootstrap

```bash
BOOTSTRAP_TAG="v0.2.0"
curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh
```

### Notes

Bare 0.2.0 normalizes to v0.2.0. Configuration dry-run supports pre-release smoke and post-install troubleshooting. Stable Formula targets the v0.2.0 archive; HEAD remains available for development.
