---
title: Documentation conventions
status: current
owner: project-maintainers
updated: 2026-10-10
---

# Documentation conventions

[中文](documentation.md)

Translation of the Chinese primary version. Commands and historical log excerpts retain their original language where applicable.

The project adopts HarnessBrew's responsibility-based classification at its own scale. Chinese is the primary version; root README, CHANGELOG, and docs documents have .en.md English counterparts. Independent-review governance is not integrated.

| Location | Responsibility |
| --- | --- |
| Root README | Purpose, environment, shortest example, navigation |
| Root CHANGELOG | Version summaries linking to detailed records |
| docs/README | Reader-oriented documentation map |
| guides | Repeatable usage, development, operations, and releasing |
| engineering | Current architecture and module constraints |
| planning | Cross-initiative priorities and planning rules |
| initiatives/<category>/<topic> | A specific work item's process, status, and evidence |
| releases/<version> | Release description, acceptance, and publication evidence |

Create directories only when content exists, and provide domain README entries. Initiative categories are feature, improvement, refactor, research, and process. Use statuses and indexes for history instead of a separate archive category.

## Metadata and responsibility

Maintained documents include title, status, owner, and updated. project-maintainers means repository maintainers. Long-lived documents use current/draft/superseded; initiatives use proposed/active/paused/completed/cancelled; releases use planned/verified/released/cancelled/withdrawn. Historical materials may retain their format with entry context.

Test commands are maintained only in [development and validation](guides/development.en.md), with Chinese authoritative and English synchronized. Initiative status lives only in its README. VERSION or a draft cannot establish publication; historical publication remains unverified, so version records currently use planned and explain the limitation.

## Links and checks

Use relative links; moving documents also requires caller and package updates. Link language counterparts mutually and prefer English targets in English navigation. Keep technical paths, commands, and historical logs unchanged. Match owner/status; updated reflects substantive revision of each language. Synchronize both languages when content changes.

Current checks cover local links, metadata, language pairs, and script regressions recorded in migration validation. Dedicated documentation CI and mandatory independent-review gates are not integrated. Maintainers review current documents every 90 days; large logs/candidates stay external or Git-ignored.
