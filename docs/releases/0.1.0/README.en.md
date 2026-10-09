---
title: 0.1.0 version record
status: planned
owner: project-maintainers
updated: 2026-10-10
---

## v0.1.0

[中文](README.md)

Translation of the Chinese primary version. Commands and historical log excerpts retain their original language where applicable.

The first public-release description completes the move from a script collection to a unified CLI and the fresh-macOS bootstrap path.

### Highlights

- Unified macos-scripts entry for setup, maintain, job, and lint.
- Standalone bootstrap installs Homebrew and brings up the CLI.
- Homebrew Formula supports tap installation.
- Installed-mode log/configuration paths keep runtime output out of repository/package directories.
- Main commands gain CLI help, validation, and errors.

### Included commands

- `macos-scripts setup shell`
- `macos-scripts setup brew configure`
- `macos-scripts setup packages`
- `macos-scripts setup git`
- `macos-scripts setup github`
- `macos-scripts maintain brew`
- `macos-scripts maintain installer list|download|create`
- `macos-scripts job list|create|status|enable|disable|delete`
- `macos-scripts lint check|fix`

### Bootstrap

On fresh macOS:

```bash
BOOTSTRAP_TAG="v0.1.0"
curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh
```

### Notes

The Formula supplies stable URL/checksum for direct tap installation. HEAD remains available for development.
