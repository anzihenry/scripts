---
title: 定时任务指南
status: current
owner: project-maintainers
updated: 2026-10-10
---

# Job 工具

[English](jobs.en.md)

`job/` 目录提供围绕 macOS `launchd` 的定时任务管理脚本，方便为仓库内其他可执行脚本创建周期性或定时运行的任务。

命令在仓库根目录执行，周期单位为分钟。

## 快速开始

- `./bin/macos-scripts job create --job-name daily-brew --script ./maintain/formulaes_casks_updater.sh --interval 720`
- `./bin/macos-scripts job create --job-name morning-macos --script ./maintain/macos_sys_usb_maker.sh --at 09:00`
- `./bin/macos-scripts job status --job-name daily-brew`
- `./bin/macos-scripts job disable --job-name daily-brew`
- `./bin/macos-scripts job delete --job-name daily-brew`

所有命令均支持 `--dry-run` 查看计划执行的操作。更多选项请运行 `./bin/macos-scripts job --help`。
