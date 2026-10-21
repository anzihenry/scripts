---
title: 使用与维护
status: current
owner: project-maintainers
updated: 2026-10-21
---

# 使用与维护

[English](using.en.md)

> 本指南中新增的日志、预检和无副作用查询规则面向当前未发布源码。固定 `v0.5.0` 的 stable 安装不会自动获得本轮行为；版本范围与本地验证方式见[安装指南](installation.md)。

## 🧭 统一 CLI

```bash
./bin/macos-scripts setup shell
./bin/macos-scripts setup brew configure
./bin/macos-scripts setup packages
./bin/macos-scripts setup git --domain gitlab.company.com --type work
./bin/macos-scripts setup github

./bin/macos-scripts maintain brew --dry-run
./bin/macos-scripts maintain installer list
./bin/macos-scripts release verify v0.5.0
./bin/macos-scripts release publish v0.5.0 --yes

./bin/macos-scripts lint check
```

> 当前 `bin/macos-scripts` 是统一入口，现有 `setup/`、`maintain/`、`lint/` 脚本继续作为内部执行器保留。
> 入口本身已拆分为 `bin/macos-scripts` + `bin/lib/*.sh`，帮助文案与参数校验逻辑不再和分发逻辑混在同一个文件里。

帮助和版本查询是纯查询：`macos-scripts --help`、`macos-scripts help <主题>`、子命令 `--help`，以及 `macos-scripts version` / `--version` / `-v` 均直接输出结果，不创建配置或日志目录、不写入或轮转日志、不获取锁，也不检查系统版本、架构或网络。独立脚本的帮助入口遵循相同规则。日志路径不可写或日志轮转参数无效时，仍可查看帮助和版本；只有真正执行功能（包括 dry-run）才初始化运行环境。未知命令、无效参数及版本查询的多余参数返回非零并给出提示。

GitHub 配置默认不带 `--force`；仅在明确需要重建已有 SSH 密钥时显式添加该选项。

## 🧰 常用工具脚本

### Shell 脚本 Lint & 格式化

```bash
./lint/lint_shell.sh           # 检查 Zsh shebang 与语法
./lint/lint_shell.sh --fix     # 兼容入口，仅检查并提示不自动格式化
```
> 无需额外依赖。仓库统一使用 Zsh，执行 shebang 校验与 `zsh -n`。ShellCheck/shfmt 不支持 Zsh，运行时验证见[开发指南](development.md)。

### Homebrew 日常维护

```bash
cd maintain
./formulaes_casks_updater.sh --dry-run  # 预览更新命令
./formulaes_casks_updater.sh            # 更新所有 Formulae/Cask，安装态下失败项写入 ~/Library/Logs/macos-scripts/brew_update_errors.log
```

### macOS 安装器下载 & USB 启动盘制作

```bash
cd maintain
# 列出可用完整安装器
./macos_sys_usb_maker.sh list

# 下载指定版本安装器（幂等、可加 --force）
./macos_sys_usb_maker.sh download --version 14.6.1

# 制作 USB 启动盘（需要 sudo，支持 --force 覆盖、--yes 跳过交互）
./macos_sys_usb_maker.sh create --volume /Volumes/MyUSB --version 14.6 -y
```
> 脚本为关键命令记录耗时，并使用锁避免并发冲突；通过 `macos-scripts` 安装态运行时，日志默认写入 `~/Library/Logs/macos-scripts/macos-installer.log`。

更多见[安装与配置](installation.md)、[发布指南](releasing.md)。
