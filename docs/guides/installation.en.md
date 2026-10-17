---
title: Installation and setup
status: current
owner: project-maintainers
updated: 2026-10-17
---

# Installation and setup

[中文](installation.md)

Translation of the Chinese primary version. Commands and historical log excerpts retain their original language where applicable.

Run commands from the repository root; after installation, use `macos-scripts` instead of `./bin/macos-scripts`.

## First bootstrap

On a fresh macOS machine without Homebrew, use the standalone bootstrap:

```bash
BOOTSTRAP_TAG="v0.5.0"
curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh -s -- --yes
```

It checks/installs Xcode CLI tools, installs Homebrew, installs `macos-scripts` through the tap, and runs `macos-scripts setup brew configure`.

Common options:

```bash
BOOTSTRAP_TAG="v0.5.0"
curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh -s -- --dry-run --yes
curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh -s -- --yes
curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh -s -- --skip-configure
```

Bootstrap logs default to `~/Library/Logs/macos-scripts/bootstrap.log`. These published examples pin a tag. If that tag is not yet on the remote, run `zsh bootstrap/install.sh` locally or complete the release first.

## Homebrew installation

Install through the repository's Formula and tap. If Homebrew is absent, bootstrap first; the Formula does not install Homebrew itself.

```bash
# 添加 tap（仓库中包含 Formula/macos-scripts.rb）
brew tap anzihenry/scripts https://github.com/anzihenry/scripts

# 安装稳定版
brew install anzihenry/scripts/macos-scripts

# 验证
macos-scripts --help
```

To install the latest development code:

```bash
brew install --HEAD anzihenry/scripts/macos-scripts
```

The stable Formula targets the `v0.5.0` source archive; bootstrap also installs stable by default. Homebrew links the CLI into `bin/` and installs scripts into `libexec/`, preserving relative paths.

Default installed CLI directories:

```bash
MACOS_SCRIPTS_LOG_DIR="$HOME/Library/Logs/macos-scripts"
MACOS_SCRIPTS_CONFIG_DIR="$HOME/.config/macos-scripts"
```

Homebrew maintenance errors go to `~/Library/Logs/macos-scripts/brew_update_errors.log`.

### Log locations

- The unified CLI and installed package use `~/Library/Logs/macos-scripts/` as the authoritative current log location.
- Direct execution of some older scripts, without `MACOS_SCRIPTS_LOG_DIR`, falls back to the script directory. These Git-ignored `*.log` files are local diagnostics rather than repository status.
- Check the log path printed by the latest command before consulting old logs in the repository root or subdirectories.

## Four steps to set up a developer environment

### 1. Terminal setup

Install Oh My Zsh, Powerlevel10k, and fonts:

```bash
cd setup
./ohmyzsh-setup.sh
```

Follow the font instructions and restart the terminal.

### 2. Homebrew configuration

Configure or repair existing Homebrew mirrors and shellenv:

```bash
./homebrew-setup.sh
```

For a fresh machine, bootstrap first. To preview from the repository root, run `./bin/macos-scripts setup brew configure --dry-run`.

### 3. Packages

Install development tools and GUI applications:

```bash
# 如需自定义安装清单，先编辑 setup/brew.conf.sh
./macos-setup.sh
```

Edit `setup/brew.conf.sh` first if needed. The script uses `setup/lib/brew_helpers.sh` for batch/per-item installation and reports success, skipped items, failures, and timing.

### 4. Git hosting SSH keys

Optionally configure SSH keys for Git hosting platforms:

```bash
./git_forge_ssh_setup.sh -d github.com -t personal
./git_forge_ssh_setup.sh -d gitlab.company.com -t work
```

## Customize package lists

- In the repository, edit the `FORMULAE_*` and `CASKS_*` arrays in `setup/brew.conf.sh`.
- In installed mode, the first `macos-scripts setup packages` copies defaults to `~/.config/macos-scripts/brew.conf.sh`; edit that copy afterward.
- Installed `setup shell` and `setup git` place backups in `~/.config/macos-scripts/backups/`.
- `macos-setup.sh` loads these arrays and installs through shared helpers.
- Set `BH_DRY_RUN=true` to print planned installation items without installing them.
