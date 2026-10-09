---
title: 文档结构迁移验证
status: completed
owner: project-maintainers
updated: 2026-10-10
---

# 文档结构迁移验证

[English](validation.en.md)

交付对象：基线提交 52f7e3f 上的当前工作区文档迁移。当前尚未提交。

## 影响清单

| 范围 | 处理 | 原因 |
| --- | --- | --- |
| 根 README / CHANGELOG | 已更新 | 精简入口并建立版本导航 |
| guides | 已更新 | 安装、使用、任务、开发验证和发布操作归类 |
| engineering | 已更新 | 架构与 CLI 分层约定 |
| planning | 已更新 | Backlog 优先级模板 |
| initiatives | 已更新 | 重构历史与迁移专题 |
| releases | 已更新 | 版本说明和清单按版本目录组织 |
| research / product / design | 不适用 | 现有文档无独立材料 |
| Agent / GitHub 专项规范 | 已检查 | 保留工具自动发现路径，更新开发验证权威引用 |
| CLI / Formula / guards | 已更新 | 默认 notes、帮助、安装包装和测试跟随新路径 |
| 历史证据 | 已迁移 | 保留历史正文，补充状态与当前指南引用 |

## 验证边界

本次验证本地路径、导航、元信息、脚本语法与回归。没有执行真实 Homebrew 安装、远端 GitHub Release 或发布操作。历史版本身份和正式发布时间待核实，迁移不补造历史验收事实。

本次按用户要求沿用目录结构并补齐双语文档；没有引入文档专门 CI 或独立评审治理门槛。

## 验证结果

2026-10-10 本地验证通过：

- Node 只读遍历校验 115 个 Markdown 本地链接与章节锚点，0 个错误。
- 根 README、CHANGELOG 与 docs 下 32 份 Markdown 均包含必要元信息。
- `zsh tests/syntax_guard.sh`：89 项通过。
- `./lint/lint_shell.sh`：通过。
- `./tests/smoke_cli.sh`：19 项通过。
- 开发指南列出的 11 个 guard：116 项通过。
- `bash tests/e2e/run_all.sh`：8 个场景、56 项断言通过；使用临时目录和命令桩，在允许 Bash `/dev/fd` 日志捕获的环境执行。
- `git diff --check`：通过。

版本 guard 确认 `docs/releases/0.5.0/README.md` 存在，release verify E2E 通过默认 notes 路径运行。发布和使用指南示例只执行适用的沙箱回归；真实安装、磁盘操作与正式发布不适用于此次结构迁移。

最终结论：本次结构迁移通过作者自检。独立评审未执行，不声称满足 HarnessBrew 完整文档治理规范。

## 双语补齐

根 README、CHANGELOG 与 docs 下 32 份文档均已提供 `.en.md` 英文配对，共 64 份文档。每组提供双向语言链接，owner/status 一致；英文导航优先链接英文文档。中文是主版本，命令、技术路径与历史结果同步保留，代码注释及日志原文不强制翻译。

2026-10-10 双语检查通过：32 组配对与元信息一致性检查、274 个本地链接和章节锚点检查均无错误；Formula 的 `ruby -c` 语法检查通过。英文根 README 和 CHANGELOG 已加入 Formula 包装清单。

中英文 66 个 Bash 可执行示例块核对通过，忽略说明性注释后无命令差异。此次补齐没有修改运行时行为，复用上节脚本回归结果。文档专门 CI 和独立评审尚未接入。
