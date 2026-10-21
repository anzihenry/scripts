---
title: 变更记录
status: current
owner: project-maintainers
updated: 2026-10-21
---

# 变更记录

[English](CHANGELOG.en.md)

此索引汇总历史发布说明，正式发布状态见[版本索引](docs/releases/README.md)。

## 未发布

- 整体审查修复：日志改用可等待子进程并在退出前排空，保留业务退出码；先校验日志链接再打开；发布参数支持选项位于 tag 前；全新机器预演保留自定义 tap 地址，并明确 stable 安装版本由 Formula 决定。文档区分未发布源码与 v0.5.0 示例。

- 帮助和 CLI 版本查询改为无副作用的纯查询：跳过目录、日志、轮转、锁和环境预检，日志路径不可写时仍可使用；bootstrap 与独立执行器先解析参数再初始化日志，版本查询拒绝多余参数。

- bootstrap 在创建日志、配置目录和运行锁前拒绝 root（含 sudo 启动），dry-run 同样受限；root 仍可无副作用地查看帮助，提示切回普通用户重试。

- bootstrap 在安装前校验 arm64/x86_64 运行架构；Rosetta 环境提示使用原生终端，保留现有 Homebrew 探测规则，不自动迁移或重装；帮助跳过检查，dry-run 同样检查。

- 统一 bootstrap、初始化、维护、发布与 lint 执行入口的 macOS 14+ 检查；旧系统或版本读取异常时在外部操作前中止，帮助和 CLI 版本查询仍可用。

- 为默认 USTC 配置增加私有备份、失败/中断回滚和并发锁；成功后删除本次备份，失败保留。配置阶段验证连通性，不再重置仓库或强制克隆 core tap。
- bootstrap 检测到已安装 macos-scripts 时跳过安装和升级，继续配置；dry-run 同步遵循。
- bootstrap 双入口统一从 /dev/tty 读取确认；无交互终端时提示 --yes 并返回非零，dry-run 免确认。
- 官方和 USTC Homebrew 安装脚本下载增加 10 秒连接、120 秒总超时；超时仍按现有复查/换源流程处理。
- bootstrap 安装或跳过已有安装后运行 macos-scripts --version 验证 CLI；失败时中止并提示修复方式，dry-run 仅预览。
- bootstrap 按 PATH、ARM 默认位置、Intel 默认位置逐个验证 Homebrew 并去重，跳过失效入口；后续操作使用选中的绝对路径。
- 为整个 bootstrap 增加运行锁，阻止并发安装；完成、失败或可捕获中断时释放，帮助和 dry-run 不占锁。
- bootstrap 失败时统一补充阶段、退出码、日志位置和恢复建议，保留原始错误；主动取消与信号中断分别处理。
- 所有入口默认统一写入 ~/Library/Logs/macos-scripts，保留 MACOS_SCRIPTS_LOG_DIR 覆盖，移除脚本目录日志回退；bootstrap 成功摘要显示实际路径、版本、配置状态和日志位置。
- 日志追加每次运行的开始分隔，包含时间、脚本名、执行模式与 PID，不记录完整参数；维护错误日志在本次首次失败时补入分隔。
- 日志写入时自动按字节轮转（默认 5 MiB、5 份归档），使用时清理 30 天前归档，支持环境变量调整并以系统文件锁保护并发；删除仓库旧位置的 4 个历史日志。
- bootstrap 后续 GitHub 配置提示及使用示例移除默认 --force，保留用户显式选择该选项。
- CLT 已有路径与新安装完成判断均验证 xcrun --find clang；已有工具链损坏时中止修复，新安装等待路径及编译器均就绪，本地和管道入口规则一致。

- 保留官方失败后自动切换 USTC，切换前验证 brew 可用性以避免重复安装；`--yes` 为两个安装器设置非交互模式，下载失败/空脚本和安装失败均明确报错。

- 统一 bootstrap 本地与管道入口的 CLT 安装和等待行为；失败/超时中止，dry-run 不触发安装或等待，并补充双入口状态矩阵测试。

- 移除 launchd 定时任务功能及 `job` CLI、实现、专属测试和使用指南；不卸载用户已有任务或删除任务日志。

- 仓库脚本、公共库、测试和 CI 统一使用系统 Zsh，修正交互输入、数组、特殊变量与退出清理的差异。
- 检查入口强制 `#!/bin/zsh` 并执行语法检查；不再依赖 ShellCheck/shfmt，`lint fix` 保留为仅检查的兼容入口。
- 新增 Zsh 迁移回归测试；Homebrew 上游安装脚本仍按其要求使用 Bash。

## 0.5.0

[版本内容](docs/releases/0.5.0/README.md)、[验证与发布清单](docs/releases/0.5.0/validation.md)。

## 0.4.0

[版本内容](docs/releases/0.4.0/README.md)、[验证与发布清单](docs/releases/0.4.0/validation.md)。

## 0.3.0

[版本内容](docs/releases/0.3.0/README.md)、[验证与发布清单](docs/releases/0.3.0/validation.md)。

## 0.2.0

[版本内容](docs/releases/0.2.0/README.md)、[验证与发布清单](docs/releases/0.2.0/validation.md)。

## 0.1.0

[版本内容](docs/releases/0.1.0/README.md)、[验证与发布清单](docs/releases/0.1.0/validation.md)。
