---
title: 使用与维护
status: current
owner: project-maintainers
updated: 2026-10-10
---

# 使用与维护

[English](using.en.md)

## 🧭 统一 CLI

```bash
./bin/macos-scripts setup shell
./bin/macos-scripts setup brew configure
./bin/macos-scripts setup packages
./bin/macos-scripts setup git --domain gitlab.company.com --type work
./bin/macos-scripts setup github --force

./bin/macos-scripts maintain brew --dry-run
./bin/macos-scripts maintain installer list
./bin/macos-scripts release verify v0.5.0
./bin/macos-scripts release publish v0.5.0 --yes

./bin/macos-scripts job list
./bin/macos-scripts lint check
```

> 当前 `bin/macos-scripts` 是统一入口，现有 `setup/`、`maintain/`、`job/`、`lint/` 脚本继续作为内部执行器保留。
> 入口本身已拆分为 `bin/macos-scripts` + `bin/lib/*.sh`，帮助文案与参数校验逻辑不再和分发逻辑混在同一个文件里。

## 🧰 常用工具脚本

### Shell 脚本 Lint & 格式化

```bash
./lint/lint_shell.sh           # 仅检查（先按 shebang 做语法检查）
./lint/lint_shell.sh --fix     # 自动使用 shfmt 格式化
```
> 依赖 `shellcheck` 与 `shfmt`（可通过 Homebrew 安装）。zsh 脚本当前会执行 `zsh -n` 语法检查；bash/sh 脚本会额外执行 shellcheck 与 shfmt。

### Launchd 定时任务工具

```bash
cd job
./scheduler.sh list                                 # 查看当前以 com.biucing.scripts.job.* 命名的任务
./scheduler.sh create \
    --job-name daily-brew \
    --script ../maintain/formulaes_casks_updater.sh \
    --interval 720                                   # 每 12 小时执行脚本
./scheduler.sh status --job-name daily-brew        # 查看任务加载状态
./scheduler.sh delete --job-name daily-brew        # 卸载并移除任务
```
> 支持 `--dry-run` 预览 plist 内容、`--at HH:MM` 定时以及 `--force` 覆盖，安装态默认把任务日志写入 `~/Library/Logs/macos-scripts/jobs/`。

### Homebrew 日常维护

```bash
cd maintain
./formulaes_casks_updater.sh --dry-run  # 预览更新命令
./formulaes_casks_updater.sh            # 更新所有 Formulae/Cask，安装态下失败项写入 ~/Library/Logs/macos-scripts/brew_update_errors.log
```

### macOS 安装器下载 & USB 启动盘制作

```bash
cd maintain
# 列出可用完整安装器
./macos_sys_usb_maker.sh list

# 下载指定版本安装器（幂等、可加 --force）
./macos_sys_usb_maker.sh download --version 14.6.1

# 制作 USB 启动盘（需要 sudo，支持 --force 覆盖、--yes 跳过交互）
./macos_sys_usb_maker.sh create --volume /Volumes/MyUSB --version 14.6 -y
```
> 脚本为关键命令记录耗时，并使用锁避免并发冲突；通过 `macos-scripts` 安装态运行时，日志默认写入 `~/Library/Logs/macos-scripts/macos-installer.log`。

更多见[安装与配置](installation.md)、[定时任务](jobs.md)、[发布指南](releasing.md)。
