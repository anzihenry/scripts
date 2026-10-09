---
title: 开发与验证
status: current
owner: project-maintainers
updated: 2026-10-10
---

# 开发与验证

[English](development.en.md)

适用于 macOS 14+，需要 Bash 3.2、Zsh，以及 `shellcheck` 和 `shfmt`。所有命令在仓库根目录执行。

## 🧪 运行验证

> 本文是测试命令的唯一权威入口；其他文档通过链接引用。

按测试层级由快到慢执行（CI 已在每次 push/PR 自动运行全部）：

```bash
zsh tests/syntax_guard.sh        # ① 语法：shebang 级 zsh -n / bash -n
./lint/lint_shell.sh             # ② 静态：bash/sh 的 shellcheck + shfmt
./tests/smoke_cli.sh             # ③ CLI：关键成功/失败路径
bash tests/e2e/run_all.sh        # ④ 进程级：沙箱 + 命令桩 E2E（8 用例）
```

> `smoke_cli.sh` 与 E2E 均使用临时目录覆盖 `MACOS_SCRIPTS_LOG_DIR` / `MACOS_SCRIPTS_CONFIG_DIR`（E2E 另覆盖 LaunchAgents），避免污染真实用户配置和日志目录。

函数级 guard 测试（zsh 运行，与 CI 的 guard 步骤一致）：

```bash
zsh tests/bootstrap_guard.sh          # bootstrap 本地文件 / curl 管道两种模式
zsh tests/cli_dispatch_guard.sh       # CLI 分发路由
zsh tests/cli_validators_guard.sh     # CLI 参数校验
zsh tests/version_consistency_guard.sh # VERSION 与各 fallback/Formula 引用一致性
zsh tests/regression_guard.sh         # 已修缺陷回归：日志、plist 原子写、陈旧锁和 release 状态
zsh tests/job_runtime_guard.sh        # job 运行时
zsh tests/job_scheduler_guard.sh      # job 调度动作
zsh tests/job_plist_guard.sh          # plist 真实写入 + plutil 校验
zsh tests/macos_installer_flow_guard.sh # 安装器流程
zsh tests/release_publish_guard.sh    # release 发布流程
zsh tests/setup_runtime_guard.sh      # setup 流程编排
zsh tests/maintain_runtime_guard.sh   # Homebrew 维护流程
```

> 以上 guard 均为 zsh 脚本，请用 `zsh tests/<name>.sh` 调用（用 bash 运行会因 zsh 语法报错）。

### 进程级 E2E（沙箱 + 命令桩）

`tests/e2e/` 提供不依赖真实环境的进程级端到端测试：把 `HOME`、配置/日志/LaunchAgents 目录全部重定向到临时沙箱，并用 `tests/e2e/shims/` 下的命令桩（`brew`、`launchctl`、`gh`、`git`、`curl` 等）拦截外部副作用，随后跑**真实脚本全流程**，断言产物文件、外部调用序列与退出码。可在每次发布前本地或 CI 执行：

```bash
bash tests/e2e/run_all.sh
```

覆盖场景：

- `job create` / `job list` / `job disable`：plist 真实写入 + `plutil` 校验 + `launchctl` 调用序列
- `release verify` / `release publish`：版本一致性、gh 创建/更新/verify-only 分支与调用参数
- `maintain brew`：brew 调用顺序、Cask 失败错误日志
- `setup brew configure`：配置流程 dry-run，防缺失 source 依赖回归
- `bootstrap/install.sh`：tap + install 调用与日志写入

> E2E 用例均为 bash 脚本，用 `bash tests/e2e/run_all.sh` 调用。发布门禁见 `.github/workflows/release.yml`（打 `v*` tag 时自动执行，含真实 macOS 上的 Formula 实装校验）。

## 🤝 贡献指南

欢迎通过 Issue 或 Pull Request 反馈问题与改进建议。在提交前请：

- 阅读遵循 [`CODE_OF_CONDUCT.md`](../../.github/CODE_OF_CONDUCT.md)，保持专业、友善的协作氛围。
- 按[「运行验证」](#-运行验证)的清单执行回归（语法 / lint / smoke / guard / E2E），命令与说明以该节为唯一权威源。

> 若涉及长耗时任务，建议附带 `log_time_start/_end` 输出截图或日志片段。
