---
title: Usage and maintenance
status: current
owner: project-maintainers
updated: 2026-10-22
---

# Usage and maintenance

[中文](using.md)

Translation of the Chinese primary version. Commands and historical log excerpts retain their original language where applicable.

> The new logging, precheck, and read-only query rules in this guide describe current unreleased source. Stable installations pinned to `v0.5.0` do not automatically acquire these changes. See the [installation guide](installation.en.md) for version scope and local inspection.

## Unified CLI

```bash
./bin/macos-scripts setup shell
./bin/macos-scripts setup brew configure
./bin/macos-scripts setup packages
./bin/macos-scripts setup git --domain gitlab.company.com --type work
./bin/macos-scripts setup github

./bin/macos-scripts maintain brew --dry-run
./bin/macos-scripts maintain installer list

./bin/macos-scripts lint check
```

`bin/macos-scripts` is the unified entry point. Scripts in `setup/`, `maintain/`, and `lint/` remain internal executors. The entry point and `bin/lib/*.sh` separate help and validation from dispatch.

Help and CLI version queries are read-only: `macos-scripts --help`, `macos-scripts help <topic>`, subcommand help flags, and `macos-scripts version` / `--version` / `-v` return directly without creating directories, writing or rotating logs, acquiring locks, or checking the OS, architecture, or network. Standalone script help follows the same rule. Unusable log paths and invalid log policies do not block these queries. Runtime initialization starts only when executing a feature, including dry-run. Unknown commands, invalid arguments, and extra version-query arguments return a nonzero status with guidance.

GitHub setup examples omit `--force`. Add it explicitly only when you intend to recreate an existing SSH key.

## Repeated execution

Setup converges to the same target state for the same arguments. Healthy resources and matching configuration skip installation or writes. Logs, timings, and online state checks may change. Maintenance can fetch newer versions; `--force` explicitly rebuilds resources.

| Feature | Repeated-run behavior |
|---|---|
| Shared configuration | Keep blocks in place; identical content leaves the target file untouched; reject malformed/duplicate/interleaved markers; preserve valid symlinks and existing permissions |
| `setup shell` | Preserve `.zshrc`, user themes and plugins, healthy repositories and local edits; stage and validate clones/fonts before moving them into place; serialize setup with a lock |
| `setup brew configure` | Skip backups and writes when blocks and remotes match; retain transactional backup/rollback for changes |
| `setup git` / `github` | Reuse matching key pairs, recover missing public keys from unencrypted private keys, separate domains while supporting unambiguous legacy identities, and skip unchanged SSH configuration |
| GitHub keys | Use environment or existing gh authentication, asking only when needed; paginate key queries before uploading; query/upload failures return nonzero and preserve local identity |
| `setup packages` | Skip installed packages and recheck partial batch successes; activate an installed local LTS without implicitly upgrading Node/npm; merge pip keys, compare mirrors, and deduplicate PATH |
| Installer downloads | Check createinstallmedia, payload image integrity, and payload OS metadata; match complete version components and select complete installers by modification time |
| USB creation | Recheck under the device lock; skip only when volume UUID, payload/Info digests, completion record, application version and boot markers match; force explicitly rebuilds |
| Homebrew maintenance | Continue updating software and metadata; failed Cask detection makes the overall result fail so it can be retried |

Forced SSH replacement retains the old keys in `backups/ssh-key.<random>/` under the configuration directory for recovery. A missing public key for an encrypted private key requires manual unlocking/export; the private key is preserved. Unverifiable existing repository directories are preserved for inspection.

Installer integrity checks read the full image. Modern payload metadata is read through a temporary read-only mount that is detached on exit. USB completion records live in `installer-state/<volume UUID>`. Manually created and older bootable media without a record conservatively require explicit force; a matching app directory alone is insufficient. Real installation and erasure still need validation on target hardware.

Upgrade Node explicitly using upstream nvm commands; setup reuses an installed LTS. [nvm usage](https://github.com/nvm-sh/nvm#long-term-support), [GitHub CLI query API](https://cli.github.com/manual/gh_api).

## Common tools

### Shell lint and formatting

```bash
./lint/lint_shell.sh           # 检查 Zsh shebang 与语法
./lint/lint_shell.sh --fix     # 兼容入口，仅检查并提示不自动格式化
```

No extra dependencies are required. All repository scripts use Zsh; lint validates the shebang and runs `zsh -n`. ShellCheck/shfmt do not support Zsh. See the [development guide](development.en.md) for runtime tests.

### Homebrew maintenance

```bash
cd maintain
./formulaes_casks_updater.sh --dry-run  # 预览更新命令
./formulaes_casks_updater.sh            # 更新所有 Formulae/Cask，安装态下失败项写入 ~/Library/Logs/macos-scripts/brew_update_errors.log
```

In installed mode, failures are written to `~/Library/Logs/macos-scripts/brew_update_errors.log`.

### macOS installers and bootable USB media

```bash
cd maintain
# 列出可用完整安装器
./macos_sys_usb_maker.sh list

# 下载指定版本安装器（幂等、可加 --force）
./macos_sys_usb_maker.sh download --version 14.6.1

# 制作 USB 启动盘（需要 sudo，支持 --force 覆盖、--yes 跳过交互）
./macos_sys_usb_maker.sh create --volume /Volumes/MyUSB --version 14.6 -y
```

The script times key commands and uses locks to prevent concurrent conflicts. USB creation requires sudo; `--force` allows replacement and `--yes` skips interaction. Installed CLI logs default to `~/Library/Logs/macos-scripts/macos-installer.log`.

See [installation and configuration](installation.en.md) and [releasing](releasing.en.md).

## Module selection, previews, and recovery

```zsh
macos-scripts setup packages --dry-run --modules node,python
macos-scripts setup packages --modules node,python
macos-scripts setup shell --dry-run
```

Modules are `node,python,ruby,go,android,packages` (all by default). Duplicates are removed and unknown modules fail before execution. `packages` installs the Formulae/Cask lists in `brew.conf.sh`; `android` writes Android/Java environment configuration. Every actual packages run still checks Command Line Tools and configures Homebrew. Postchecks only validate selected language modules. Stage summaries report timing, completed/failed/pending stages, and recovery guidance.

These two setup previews perform no network calls, installations, configuration/log/lock creation, or evaluation of the user package configuration. CLI and standalone entry points share argument parsing. Other commands may query local/remote state and write logs during dry-run; consult their help.

Defaults live in `setup/lib/setup_defaults.sh`. Override with environment variables: `SETUP_NPM_REGISTRY`, `SETUP_PIP_INDEX`, `SETUP_PIP_HOST`, `SETUP_GEM_SOURCE`, `SETUP_GOPROXY`, `SETUP_GOPATH`, `SETUP_JAVA_HOME`, and `SETUP_ANDROID_HOME`. Homebrew keeps USTC defaults. Multiple pip keys are staged together and committed once; failure preserves the original file.

Configuration writes lock the resolved resource path, including symlink targets. Homebrew configuration holds the lock across snapshots, writes, and rollback. Installation, setup, and maintenance coordinate by Homebrew prefix; bootstrap releases its lock before the separate configuration CLI reacquires it. Shell and SSH setup also have operation locks. System Zsh `zsystem flock` releases locks on process exit. The default wait is 10 seconds, configurable with `MACOS_SCRIPTS_LOCK_TIMEOUT` (0–9999). Lock files persist under `/tmp/macos-scripts-locks-<UID>/`; **do not delete them**. Uncertain legacy directory locks require inspection.

Advisory locks coordinate cooperating project processes, not editors or manual commands. Synchronous nested calls may reuse a parent transaction lock; do not fork parallel writers inside a transaction. SIGKILL/power loss releases kernel locks but cannot run rollback. Completed installations remain; retries inspect actual state, and retained backups support manual recovery. Signal exit codes are INT=130, TERM=143, HUP=129. Recorder failures report incomplete logs without replacing the business exit code.

Common implementations live in `lib/config_writer.sh`, `lib/command_runtime.sh`, `lib/resource_lock.sh`, and `lib/workflow.sh`; old writer/command import paths remain compatible. SSH identity, configuration, GitHub API, and connection output are separate setup libraries.

Homebrew 配置的未完成事务在下次运行时检查：内容匹配检查点则自动恢复；后续编辑、备份损坏或未记录写入会停止，保留备份并提示人工处理。恢复成功保留旧备份，新事务成功删除本次备份。
