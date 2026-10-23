---
title: 架构与模块
status: current
owner: project-maintainers
updated: 2026-10-23
---

# 架构与模块

[English](architecture.en.md)

目标环境为 macOS 14+、系统 Zsh。

## 🧱 当前模块结构

- `bin/lib/`：统一 CLI 分层模块（帮助文案、参数校验、参数转发、命令分发、共享运行时）
- `packages/zsh-kit/lib/`：独立的日志、执行器、阶段、资源锁和原子配置写入组件
- `lib/`：应用默认值、旧 API 适配与 UI；不再保存公共机制副本
- `setup/lib/`：setup 运行时、语言环境、安装后校验与业务事务模块
- `maintain/lib/`：Homebrew 更新与安装器/USB 制作的参数解析与流程编排模块
- `lib/utils.sh`：日志路径解析、运行时 helper、依赖检查
- `tests/`：语法护栏、smoke、函数级 guard 与沙箱 E2E 四层测试


`bin/macos-scripts` 初始化日志/配置路径并装配 CLI，业务执行器负责系统操作。共享日志与依赖检测位于 `lib/`，Homebrew 安装 helper 位于 `setup/lib/`。

[CLI 分层规则](cli-layering.md)、[开发验证](../guides/development.md)。

公共接口与迁移规则见 [实施约定](reuse-plan.md) 和 [zsh-kit](../../packages/zsh-kit/README.md)。
