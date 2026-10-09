---
title: Release operations
status: current
owner: project-maintainers
updated: 2026-10-10
---

# Release operations

[中文](releasing.md)

Translation of the Chinese primary version. Commands and historical log excerpts retain their original language where applicable.

## GitHub Release

Use the unified CLI for release operations:

```bash
./bin/macos-scripts release verify v0.5.0
./bin/macos-scripts release publish v0.5.0 --yes
```

- `release verify <tag>` checks the tag, gh authentication, and existing release state.
- `release publish <tag>` idempotently creates or updates a release.
- Bare version numbers are normalized by adding `v`: `0.4.0` becomes `v0.4.0`; `v0.5.0` stays unchanged.
- Default notes are `docs/releases/<version>/README.md` (Chinese).
- Use `--notes-file <path>` to select another file, including `README.en.md`.

### Single version authority

The root `VERSION` file is authoritative, currently `0.5.0`. The CLI version/help reads it; local bootstrap prefers it and piped execution uses a built-in fallback. The Formula installs VERSION into libexec.

Verify/publish compares the target tag to VERSION and the Formula reference. Publish aborts on inconsistency. Update VERSION and the Formula URL/checksum for a new release, then check consistency with verify.

## Release sequence

1. Update VERSION, CLI/bootstrap fallbacks, and Formula URL; create `docs/releases/<version>/README.md`.
2. Run [development validation](development.en.md) and record the candidate commit and results.
3. Review and commit version changes, create and push the version tag, and wait for the release workflow.
4. Compute SHA-256 from the `refs/tags/<tag>` source archive and update the Formula on main. Do not move a frozen tag.
5. After Formula installation and release gates pass, run publish and record the official URL, artifact identity, and publication time.

Each version's `validation.md` contains its checklist. Historical checklists do not prove current acceptance or official publication.
