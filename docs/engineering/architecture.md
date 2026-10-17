---
title: 架构与模块
status: current
owner: project-maintainers
updated: 2026-10-17
---

# 架构与模块

[English](architecture.en.md)

目标环境为 macOS 14+、系统 Zsh。

## 🧱 当前模块结构

- `bin/lib/`：统一 CLI 分层模块（帮助文案、参数校验、参数转发、命令分发、共享运行时）
- `setup/lib/`：setup 运行时、配置写入、语言环境、安装后校验模块
- `maintain/lib/`：Homebrew 更新与安装器/USB 制作的参数解析与流程编排模块
- `lib/utils.sh`：日志路径解析、运行时 helper、依赖检查
- `tests/`：语法护栏、smoke、函数级 guard 与沙箱 E2E 四层测试


`bin/macos-scripts` 初始化日志/配置路径并装配 CLI，业务执行器负责系统操作。共享日志与依赖检测位于 `lib/`，Homebrew 安装 helper 位于 `setup/lib/`。

[CLI 分层规则](cli-layering.md)、[开发验证](../guides/development.md)。
