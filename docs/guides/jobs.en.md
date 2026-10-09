---
title: Scheduled jobs
status: current
owner: project-maintainers
updated: 2026-10-10
---

# Job tools

[中文](jobs.md)

Translation of the Chinese primary version. Commands and historical log excerpts retain their original language where applicable.

The `job/` directory manages macOS `launchd` jobs for other executable scripts in the repository, either periodically or at a specified time.

Run commands from the repository root. Intervals are measured in minutes.

## Quick start

- `./bin/macos-scripts job create --job-name daily-brew --script ./maintain/formulaes_casks_updater.sh --interval 720`
- `./bin/macos-scripts job create --job-name morning-macos --script ./maintain/macos_sys_usb_maker.sh --at 09:00`
- `./bin/macos-scripts job status --job-name daily-brew`
- `./bin/macos-scripts job disable --job-name daily-brew`
- `./bin/macos-scripts job delete --job-name daily-brew`

Commands support `--dry-run` to preview their planned actions. Run `./bin/macos-scripts job --help` for more options.
