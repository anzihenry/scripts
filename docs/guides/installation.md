---
title: 安装与初始化
status: current
owner: project-maintainers
updated: 2026-10-10
---

# 安装与初始化

[English](installation.en.md)

命令在仓库根目录执行；安装态使用 `macos-scripts` 替代 `./bin/macos-scripts`。

## ⚡ 首次 Bootstrap

如果这是台全新的 macOS，且系统里还没有 Homebrew，优先使用独立 bootstrap 入口：

```bash
BOOTSTRAP_TAG="v0.5.0"
curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh -s -- --yes
```

这个入口会依次完成：

1. 检查并安装 Xcode CLI
2. 安装 Homebrew
3. 通过 tap 安装 `macos-scripts`
4. 自动执行 `macos-scripts setup brew configure`

常用选项：

```bash
BOOTSTRAP_TAG="v0.5.0"
curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh -s -- --dry-run --yes
curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh -s -- --yes
curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh -s -- --skip-configure
```

> bootstrap 日志默认写入 `~/Library/Logs/macos-scripts/bootstrap.log`。
> 以上命令按正式发布口径固定到 tag。当前仓库尚未创建对应远端 tag 时，请先在本地执行 `zsh bootstrap/install.sh`，或先完成版本发布。

## 🍺 Homebrew 安装

仓库已经具备 Homebrew Formula 结构，推荐通过 tap 安装。

如果系统尚未安装 Homebrew，请先使用上面的独立 bootstrap 入口，不要试图靠 formula 自举。

```bash
# 添加 tap（仓库中包含 Formula/macos-scripts.rb）
brew tap anzihenry/scripts https://github.com/anzihenry/scripts

# 安装稳定版
brew install anzihenry/scripts/macos-scripts

# 验证
macos-scripts --help
```

如需安装开发中的最新版本，可选：

```bash
brew install --HEAD anzihenry/scripts/macos-scripts
```

> 当前 stable Formula 将固定到 `v0.5.0` 源码归档；bootstrap 默认也会安装 stable 版本。

安装后 Homebrew 会把 CLI 入口链接到 `bin/`，并把仓库脚本安装到 `libexec/`，从而保留当前相对路径结构。

CLI 安装后默认使用这些目录：

```bash
MACOS_SCRIPTS_LOG_DIR="$HOME/Library/Logs/macos-scripts"
MACOS_SCRIPTS_CONFIG_DIR="$HOME/.config/macos-scripts"
```

例如 `macos-scripts maintain brew` 的错误日志默认会写入 `~/Library/Logs/macos-scripts/brew_update_errors.log`。
`macos-scripts job create` 的默认任务日志会写入 `~/Library/Logs/macos-scripts/jobs/`。

### 日志位置说明

- 通过统一 CLI 或 Homebrew 安装态运行时，以 `~/Library/Logs/macos-scripts/` 为当前日志的权威位置。
- 直接运行底层脚本且未设置 `MACOS_SCRIPTS_LOG_DIR` 时，部分旧入口会回退到脚本目录写日志；这些 `*.log` 均被 Git 忽略，只用于本机诊断，不代表仓库状态。
- 排查最新一次运行时，先查看命令输出的“日志文件位置”，不要混用仓库根目录或子目录中遗留的历史日志。

## ️💻 四步搭建开发环境

1. **终端美化** – 安装 Oh My Zsh、Powerlevel10k、字体等：
    ```bash
    cd setup
    ./ohmyzsh-setup.sh
    ```
    > 完成后请根据提示设置终端字体，并重启终端。

2. **校准 Homebrew（镜像 + shellenv）**：
    ```bash
    ./homebrew-setup.sh
    ```
    > 该步骤只负责配置/修复已有 Homebrew；如果是全新机器，请先使用上面的 bootstrap 入口完成首次安装。
    > 如需非破坏性预演，可执行 `./bin/macos-scripts setup brew configure --dry-run`。

3. **批量安装开发工具 / GUI 应用**：
    ```bash
    # 如需自定义安装清单，先编辑 setup/brew.conf.sh
    ./macos-setup.sh
    ```
    > 脚本使用 `setup/lib/brew_helpers.sh` 以批量/逐项方式安装，并输出成功/跳过/失败统计与耗时。

4. **（可选）配置多平台 SSH 密钥**：
    ```bash
    ./git_forge_ssh_setup.sh -d github.com -t personal
    ./git_forge_ssh_setup.sh -d gitlab.company.com -t work
    ```

## 🔧 自定义安装清单

- 仓库内运行时，编辑 `setup/brew.conf.sh` 调整 `FORMULAE_*`、`CASKS_*` 数组即可。
- Homebrew 安装态运行时，首次执行 `macos-scripts setup packages` 会自动把默认配置复制到 `~/.config/macos-scripts/brew.conf.sh`，后续编辑该文件即可。
- `macos-scripts setup shell` 与 `macos-scripts setup git` 在安装态下会把备份文件写入 `~/.config/macos-scripts/backups/`，避免把运行产物散落到仓库或安装目录。
- `macos-setup.sh` 会自动加载这些数组并通过新封装的 helper 执行安装。
- 可在运行前通过设置环境变量 `BH_DRY_RUN=true` 做干跑测试（只输出将安装的项目，不实际执行）。
