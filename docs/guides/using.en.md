---
title: Usage and maintenance
status: current
owner: project-maintainers
updated: 2026-10-17
---

# Usage and maintenance

[中文](using.md)

Translation of the Chinese primary version. Commands and historical log excerpts retain their original language where applicable.

## Unified CLI

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

./bin/macos-scripts lint check
```

`bin/macos-scripts` is the unified entry point. Scripts in `setup/`, `maintain/`, and `lint/` remain internal executors. The entry point and `bin/lib/*.sh` separate help and validation from dispatch.

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
