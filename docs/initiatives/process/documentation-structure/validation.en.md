---
title: Documentation migration validation
status: completed
owner: project-maintainers
updated: 2026-10-10
---

# Documentation migration validation

[中文](validation.md)

Translation of the Chinese primary version. Commands and historical log excerpts retain their original language where applicable.

Delivery scope: current worktree migration on baseline commit 52f7e3f. Changes are not yet committed.

## Impact inventory

| Area | Treatment | Reason |
| --- | --- | --- |
| Root README / CHANGELOG | Updated | Concise entry and version navigation |
| guides | Updated | Installation, usage, jobs, development checks, releasing |
| engineering | Updated | Architecture and CLI layering |
| planning | Updated | Backlog priorities |
| initiatives | Updated | Refactoring history and migration |
| releases | Updated | Per-version descriptions and checklists |
| research / product / design | Not applicable | No separate materials |
| Agent / GitHub instructions | Inspected | Preserve discovery paths, update verification authority |
| CLI / Formula / guards | Updated | Default notes, help, installed documents, tests |
| Historical evidence | Migrated | Retain original content and add current-guide context |

## Validation boundaries

Checks cover local paths, navigation, metadata, syntax, and regressions. Real Homebrew installation, remote Releases, and publication were not performed. Historical artifact identities and publication times await verification; migration does not invent acceptance evidence.

The requested structure and bilingual documents are supplied. Dedicated documentation CI and independent-review governance are not introduced.

## Structural validation results

Local checks passed on 2026-10-10, before bilingual additions:

- Read-only Node traversal: 115 Markdown local links/anchors, zero errors.
- All 32 root/docs documents had required metadata.
- Syntax guard: 89 checks passed.
- Shell lint: passed.
- CLI smoke: 19 checks passed.
- Eleven development-guide guards: 116 checks passed.
- E2E: eight scenarios and 56 assertions passed with temporary directories/stubs and Bash /dev/fd log capture permitted.
- git diff --check: passed.

The version guard confirms docs/releases/0.5.0/README.md exists. Release verify E2E used the default notes path successfully. Usage/release examples received applicable sandbox checks; real installation, disk operations, and publication were outside migration.

Conclusion: author checks passed. Independent review was not performed; this does not claim full HarnessBrew documentation-governance compliance.

## Bilingual follow-up

All 32 root/docs documents have English counterparts: 64 documents with mutual language links, matching owner/status, and English navigation. Chinese is the primary version. Translations preserve commands, technical paths, limitations, and historical results. Chinese code comments and log excerpts remain original-language evidence.

On 2026-10-10, checks passed for all 32 pairs, required metadata, and 274 local links/anchors, with zero errors. Formula validation with `ruby -c` passed; root README.en.md and CHANGELOG.en.md are included in package installation.

All 66 executable Bash example blocks match across languages after ignoring explanatory comments. This follow-up changes no runtime behavior and reuses the structural migration's script regression results. Dedicated documentation CI and independent review remain unintegrated.
