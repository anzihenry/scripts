---
applyTo: "maintain/**/*.sh"
description: "维护脚本规范"
---
# Maintain 目录脚本指南

## 背景与目标
- 背景：`maintain/` 目录包含 Homebrew 更新、安装器制作等日常维护脚本，需要在现有环境上安全运行。
- 目标：
	- 兼容 macOS 自带 Bash 3.x，避免 GNU-only 特性。
	- 在批量或耗时操作中提供序号、进度与耗时提示，必要时写入错误日志。
	-支持可选参数（`--force`、`--dry-run`、`--yes`）以便非交互式运行。

## 适用范围
- 文件/目录：`maintain/` 及其子目录（如 `formulaes_casks_updater.sh`、`macos_sys_usb_maker.sh`）。
- 关键约束：
	- macOS 版本：14+。
	- Shell 类型：`bash`（系统默认 3.x），禁止依赖 Bash 4+ 新特性。
	- 权限：默认无需 `sudo`，若必须则提前提示并要求确认。

## 代码风格要求
### 头部与基础设置
- Shebang：`#!/bin/bash`，保留 `# filepath:` 注释。
- 严格模式：酌情使用 `set -euo pipefail`；如因 Bash 3.x 限制无法启用 `-o pipefail`，需说明并使用替代检查逻辑。

### 日志与输出
- 引入颜色库：`source "$SCRIPT_DIR/../lib/colors.sh"`。
- 步骤日志：使用 `print_header`、`info`、`success`、`warning`、`error`，并为批量任务输出 `当前序号/总数`。
- 耗时统计：适用时调用 `log_time_start` / `log_time_end`。

### 命名规范
- 函数：小写 + 下划线（如 `process_cask()`）。
- 局部变量：使用 `local`，全局常量采用大写命名，如 `ERROR_LOG`、`EXCLUDE_PATTERN`。

## 功能与结构约束
### 依赖检测
- 使用 `command -v` 检查 Homebrew、`hdiutil`、`softwareupdate` 等依赖，缺失时输出补救步骤。

### 参数与开关
- 支持 `--force`、`--dry-run`、`--yes` 之类的开关，并在帮助信息中说明用途。
- 幂等保障：在执行破坏性操作（删除、覆盖、下载）前检测现有状态，并尊重用户输入的开关。

### 复用组件
- 若涉及 Homebrew 逻辑，可复用 `setup/lib/brew_helpers.sh` 或抽取公共函数。
- 对重复的日志/统计操作考虑封装小函数，保持代码简洁。

## 错误处理与提示
- 失败时调用 `error` 并写入 `brew_update_errors.log` 或自定义日志文件，包含时间戳与上下文。
- 提供下一步建议：重试、检查网络、手动执行等。
- 长耗时任务显示进度、支持中断或恢复（例如可重复执行同一脚本）。

## 验证与交付
- 语法检查：`bash -n maintain/<script>.sh`。
- Lint：`./lint/lint_shell.sh`。
- 手动测试：按脚本用途提供示例命令（例如 `./maintain/formulaes_casks_updater.sh --dry-run`）。

## 推荐 Prompt
- “基于《Maintain 目录脚本指南》，为 `maintain/formulaes_casks_updater.sh` 增加批量更新日志与错误记录。”
- “请按指南为新脚本实现 `--dry-run`，并确保兼容 Bash 3.x。”
- “依据该指南优化长耗时任务的进度输出和失败重试提示。”

## 维护说明
- 负责人：维护脚本负责人。
- 更新频率：每季度或 Homebrew/macOS 维护策略调整时复查。
- 历史记录：关键变更记录在 PR 描述与 `brew_update_errors.log` 使用说明中。
