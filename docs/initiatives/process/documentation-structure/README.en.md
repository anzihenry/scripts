---
title: Documentation structure migration
status: completed
owner: project-maintainers
updated: 2026-10-10
---

# Documentation structure migration

[中文](README.md)

Translation of the Chinese primary version. Commands and historical log excerpts retain their original language where applicable.

Status: completed. Owner: project-maintainers. This entry is the sole task-status source.

## Goal and scope

Adopt HarnessBrew's responsibility-based documentation structure, split the root README, migrate refactoring history and version records, and update release CLI, help, tests, and package references. Use the new paths directly without compatibility redirects.

## Completion criteria

- Existing content is reachable from new indexes; old directories contain no maintained documents.
- Repository links work and default release notes come from the new directory.
- Syntax, lint, smoke, guard, and E2E checks pass.

## Navigation

[Documentation map](../../../README.en.md), [conventions](../../../documentation.en.md), [validation record](validation.en.md).

The root README, CHANGELOG, and docs documents now have English counterparts. HarnessBrew's independent-review governance has not been integrated.

## Delivery

Migration, reference updates, and the default release-path switch are complete. Local links and full regression checks passed; see [validation](validation.en.md). Changes are not yet committed. Verifying remote historical releases is separate from structural migration; maintainers can add version evidence later.
