---
applyTo: "job/**/*.sh"
description: "Launchd 定时任务脚本规范"
---
# Job 脚本指南

> 本指南用于约束 `job/` 目录下的 Launchd 定时任务工具脚本，补充《Shell 脚本通用指南》的要求。

## 背景与目标
- 背景：`job/` 目录包含用于管理 macOS `launchd` 定时任务的脚本。
- 目标：
  - 提供安全、幂等的任务创建、更新、启停功能。
  - 通过彩色日志与耗时记录提升可观测性。
  - 兼容 macOS 14+ 用户态 `launchctl` 命令（禁止 `sudo`）。

## 适用范围
- 文件/目录：`job/**/*.sh`。
- 关键约束：
  - Shell：统一使用 `#!/bin/zsh`。
  - 路径：默认操作 `~/Library/LaunchAgents` 与 `~/Library/Logs`，禁止修改系统级目录。
  - 权限：所有命令以当前用户执行，若需提升权限需在日志中说明风险并征得确认。

## 代码风格要求
- 头部：保留 `# filepath: ...` 注释，启用 `set -euo pipefail`。
- 日志：`source "$SCRIPT_DIR/../lib/colors.sh"`，使用 `print_header`、`info`、`success`、`warning`、`error`、`highlight`、`log_time_start`、`log_time_end`。
- 输出：描述使用中文，命令与路径保持英文。
- 命名：函数为小写加下划线，局部变量使用 `local` 限定；常量使用全大写或明显前缀。

## 功能与结构约束
- 依赖检测：在使用 `launchctl`、`plutil` 等命令前执行 `command -v` 检查。
- 参数：脚本需提供 `--help` 并明确列出支持的操作（例如创建、启停、删除、dry-run、force）。
- 幂等：对同名任务重复执行时应检测已存在的 `.plist` 文件，默认拒绝覆盖，提供 `--force`。
- 安全：对写入文件、加载任务等动作在执行前打印中文提示；失败时输出错误并返回非零值。
- 结构：
  - 将核心逻辑拆分为函数，避免巨大 `case` 块。
  - 生成 `.plist` 前验证目标脚本存在且可执行。
  - 允许通过 `--dry-run` 查看将执行的命令。

## 错误处理与提示
- 捕获异常调用 `error`，提示用户如何排查（如 `launchctl print`）。
- 需要重试时明确最大重试次数和等待策略。
- 对可能的冲突（例如 label 重复、target 不可执行）在执行前阻止并给出解决方案。

## 验证与交付
- 语法检查：`zsh -n job/<script>.sh`。
- Lint：`./lint/lint_shell.sh`。
- 手动验证：建议创建带 `--dry-run` 的示例命令，提示如何查看任务状态与日志。

## 推荐 Prompt
- “根据 Job 脚本指南，为 `job/scheduler.sh` 增加 `--interval` 与 `--at` 调度方式。”
- “请优化 `job/scheduler.sh` 的日志输出，确保所有 launchctl 调用有彩色提示。”
- “在遵循指南的前提下，实现 `job/list_jobs.sh` 脚本列出全部任务。”

## 维护说明
- 负责人：脚本仓库维护者。
- 更新频率：每季度或 macOS `launchd` 行为发生变化时同步。
