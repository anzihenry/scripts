---
title: Development and validation
status: current
owner: project-maintainers
updated: 2026-10-22
---

# Development and validation

[中文](development.md)

Translation of the Chinese primary version. Commands and historical log excerpts retain their original language where applicable.

Requires macOS 14+ and its system Zsh; no ShellCheck/shfmt installation is needed. Run all commands from the repository root.

Repository scripts, tests, and stubs use `#!/bin/zsh`. ShellCheck/shfmt do not support Zsh, so lint checks interpreter policy and syntax; guards and E2E cover runtime semantics. `lint --fix` remains a compatibility alias that reports it does not format Zsh. Downloaded upstream Homebrew installers still run with `/bin/bash`.

## Run validation

This guide is the single maintained source for test commands; other documents link here. The Chinese version is authoritative and this English version mirrors it.

Run tests from faster checks to slower suites; CI runs them on pushes and pull requests:

```bash
zsh lint/sync_bootstrap.sh --check # Bootstrap 内嵌代码一致性
zsh tests/syntax_guard.sh        # ① 语法：统一 #!/bin/zsh 与 zsh -n
./lint/lint_shell.sh             # ② 检查：Zsh shebang 与语法（同一检查入口）
./tests/smoke_cli.sh             # ③ CLI：关键成功/失败路径
zsh tests/e2e/run_all.sh         # ④ 进程级：沙箱 + 命令桩 E2E（5 用例）
```

Smoke and E2E tests override `MACOS_SCRIPTS_LOG_DIR` and `MACOS_SCRIPTS_CONFIG_DIR` with temporary directories to isolate user files.

Function guards, matching the CI guard step:

```bash
zsh tests/bootstrap_guard.sh          # bootstrap 双入口：root 保护、架构、运行锁/并发/中断、PTY 确认、CLT、Homebrew 换源/dry-run
zsh tests/cli_dispatch_guard.sh       # CLI 分发路由
zsh tests/cli_validators_guard.sh     # CLI 参数校验
zsh tests/version_consistency_guard.sh # VERSION 与各 fallback/Formula 引用一致性
zsh tests/regression_guard.sh         # Fixed-defect regressions: logs, stale locks, release state
zsh tests/zsh_migration_guard.sh      # Zsh 迁移：交互、数组、安装 helper 与进程隔离
zsh tests/macos_installer_flow_guard.sh # 安装器流程
zsh tests/release_publish_guard.sh    # release 发布流程
zsh tests/setup_runtime_guard.sh      # setup 流程编排
zsh tests/maintain_runtime_guard.sh   # Homebrew 维护流程
zsh tests/idempotence_guard.sh       # 重复执行、失败恢复、资源复用与安装器状态
zsh tests/reliability_guard.sh      # 多进程配置、回滚互斥、信号、错误传播、预览一致性
```

Query regressions cover CLI and standalone help, CLI versions, piped bootstrap help, fresh directories, unusable paths, and existing logs and locks. Command stubs verify that queries do not check the system or network, create directories, rotate logs, or modify locks.

Bootstrap root tests fix the effective-UID condition only in a temporary script copy; they do not run sudo or change the real UID. They verify early rejection without writes and help access for root.

Invoke the listed guards with `zsh tests/<name>.sh`, as documented. Zsh-specific guards fail when invoked with Bash.

### Process-level E2E with sandboxes and command stubs

`tests/e2e/` redirects HOME, configuration, and logs into temporary sandboxes. Stubs in `tests/e2e/shims/` intercept brew, gh, git, curl, and other external commands. The actual scripts run end to end; assertions inspect produced files, call sequences, and exit codes.

```bash
zsh tests/e2e/run_all.sh
```

Coverage:

- `release verify/publish`: version consistency and gh create/update/verify-only branches and arguments.
- `maintain brew`: brew call order and Cask failure logs.
- `setup brew configure`: dry-run, real temporary Git configuration, repeated execution, staged failure/interruption rollback, backups, and locking.
- `bootstrap/install.sh`: tap/install calls and log writes.

E2E scripts use Zsh. The `.github/workflows/release.yml` gate runs for `v*` tags and includes actual Formula installation on macOS.

## Contributing

Report issues or suggest improvements through Issues or Pull Requests. Before committing, follow the [code of conduct](../../.github/CODE_OF_CONDUCT.md) (Chinese) and run the [validation suite](#run-validation). For long operations, include `log_time_start/_end` logs or screenshots where useful.

## Shared code and compatibility validation

After changing logging, resource locks, macOS requirements, or `first_line`, regenerate standalone bootstrap code with `zsh lint/sync_bootstrap.sh`, then run the checklist above. CI and release gates enforce `--check`.

CI records OS, architecture, and system Zsh versions. Repository variable `MACOS_TEST_RUNNERS` accepts a JSON array of available runner labels, defaulting to `["macos-latest"]`. Configure available Intel/Apple Silicon runners to run the same suite on each; use labels supported by your actual GitHub or self-hosted infrastructure.

Before release, record the commit and results for macOS 14 arm64, macOS 14 x86_64, and a newer supported macOS. Run this full checklist on each and mark unavailable combinations unverified. Stubbed tests do not prove real Homebrew installation, image mounting, or USB creation; validate those separately on recoverable test machines/media.
