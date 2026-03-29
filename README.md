# macOS 高效自动化脚本库

本仓库收集了一组经过打磨的 Shell 脚本，用于在全新的 macOS 上极速搭建开发环境、封装日常维护操作，并提供彩色、透明的执行日志。

## ✨ 亮点能力

- **分步式初始化流程**：从终端美化、Homebrew 安装到常用开发工具与 GUI 应用的批量部署，一套脚本走完全部流程。
- **幂等与安全**：核心脚本内置状态检测、重试与互斥锁，可重复运行而不会破坏现有环境。
- **国内网络加速**：自动配置 Homebrew、npm、pip、gem 等镜像，提高下载成功率与速度。
- **模块化组件**：所有功能按需调用，可单独运行 `homebrew-setup.sh`、`macos_sys_usb_maker.sh` 等完成特定工作。
- **统一日志与耗时统计**：`lib/colors.sh` 提供丰富的彩色日志 API 与计时器，执行过程可视化、一目了然。
- **结构化配置 & 辅助库**：`brew.conf.sh` 管理安装清单，`setup/lib/brew_helpers.sh`、`maintain/lib/macos_installer_utils.sh` 等复用工具帮助保持代码整洁可测。

## 📂 目录结构

```
.
├── README.md
├── LICENSE
├── lib/
│   └── colors.sh                 # 彩色日志 & 计时工具库
├── lint/
│   └── lint_shell.sh             # Shell 脚本 lint & 格式化工具
├── job/
│   ├── scheduler.sh              # Launchd 定时任务管理工具
│   └── README.md                 # 使用说明与示例
├── maintain/
│   ├── macos_sys_usb_maker.sh    # macOS 安装器下载 & USB 启动盘制作
│   ├── formulaes_casks_updater.sh# Homebrew 批量更新工具
│   └── lib/
│       └── macos_installer_utils.sh # 安装器辅助函数
└── setup/
     ├── brew.conf.sh              # Homebrew 安装清单（Formulae & Casks）
     ├── macos-setup.sh            # [步骤3] 批量安装开发工具 & GUI 应用
     ├── homebrew-setup.sh         # [步骤2] 安装 Homebrew 并配置镜像
     ├── ohmyzsh-setup.sh          # [步骤1] 终端环境与主题
     ├── git_forge_ssh_setup.sh    # [可选] Git 平台 SSH 密钥自动化
     └── lib/
          └── brew_helpers.sh       # Homebrew 安装/重试/汇总辅助函数
```

## 🚀 快速开始

```bash
# 克隆仓库
git clone https://github.com/anzihenry/scripts.git
cd scripts

# 统一 CLI 入口
chmod +x bin/macos-scripts
./bin/macos-scripts --help
```

## ⚡ 首次 Bootstrap

如果这是台全新的 macOS，且系统里还没有 Homebrew，优先使用独立 bootstrap 入口：

```bash
BOOTSTRAP_TAG="v0.1.0"
curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh
```

这个入口会依次完成：

1. 检查并安装 Xcode CLI
2. 安装 Homebrew
3. 通过 tap 安装 `macos-scripts`
4. 自动执行 `macos-scripts setup brew configure`

常用选项：

```bash
BOOTSTRAP_TAG="v0.1.0"
curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh -s -- --dry-run
curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh -s -- --yes
curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh -s -- --skip-configure
```

> bootstrap 日志默认写入 `~/Library/Logs/macos-scripts/bootstrap.log`。
> 以上命令按正式发布口径固定到 tag。当前仓库尚未创建对应远端 tag 时，请先在本地执行 `zsh bootstrap/install.sh`，或先完成版本发布。

## 🧭 统一 CLI

```bash
./bin/macos-scripts setup shell
./bin/macos-scripts setup brew configure
./bin/macos-scripts setup packages
./bin/macos-scripts setup git --domain gitlab.company.com --type work
./bin/macos-scripts setup github --force

./bin/macos-scripts maintain brew --dry-run
./bin/macos-scripts maintain installer list
./bin/macos-scripts release verify v0.1.0
./bin/macos-scripts release publish v0.1.0 --yes

./bin/macos-scripts job list
./bin/macos-scripts lint check
```

> 当前 `bin/macos-scripts` 是统一入口，现有 `setup/`、`maintain/`、`job/`、`lint/` 脚本继续作为内部执行器保留。

## 🚢 Release 发布

对于 GitHub Release，优先使用统一 CLI，而不是直接调用底层脚本：

```bash
./bin/macos-scripts release verify v0.1.0
./bin/macos-scripts release publish v0.1.0 --yes
```

说明：

- `release verify <tag>` 只检查 tag、`gh` 登录状态和现有 release 状态
- `release publish <tag>` 会按幂等语义创建或更新 release
- `<tag>` 支持传 `0.1.0` 或 `v0.1.0`，CLI 会自动规范化为 `v0.1.0`
- 默认自动使用 `releases/<tag>-release-notes.md` 作为 release notes
- 如需自定义文案文件，可追加 `--notes-file <path>`

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

> 当前 stable Formula 已固定到 `v0.1.0` 源码归档；bootstrap 默认也会安装 stable 版本。

安装后 Homebrew 会把 CLI 入口链接到 `bin/`，并把仓库脚本安装到 `libexec/`，从而保留当前相对路径结构。

CLI 安装后默认使用这些目录：

```bash
MACOS_SCRIPTS_LOG_DIR="$HOME/Library/Logs/macos-scripts"
MACOS_SCRIPTS_CONFIG_DIR="$HOME/.config/macos-scripts"
```

例如 `macos-scripts maintain brew` 的错误日志默认会写入 `~/Library/Logs/macos-scripts/brew_update_errors.log`。
`macos-scripts job create` 的默认任务日志会写入 `~/Library/Logs/macos-scripts/jobs/`。

## ️💻 四步搭建开发环境

1. **终端美化** – 安装 Oh My Zsh、Powerlevel10k、字体等：
    ```bash
    cd setup
    ./ohmyzsh-setup.sh
    ```
    > 完成后请根据提示设置终端字体，并重启终端。

2. **安装 Homebrew（含镜像配置）**：
    ```bash
    ./homebrew-setup.sh
    ```
    > 安装过程中会自动检测 Xcode CLI、网络与磁盘空间；多次重试后仍失败会给出明确提示。

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

## 🧰 常用工具脚本

### Shell 脚本 Lint & 格式化

```bash
./lint/lint_shell.sh           # 仅检查（先按 shebang 做语法检查）
./lint/lint_shell.sh --fix     # 自动使用 shfmt 格式化
```
> 依赖 `shellcheck` 与 `shfmt`（可通过 Homebrew 安装）。zsh 脚本当前会执行 `zsh -n` 语法检查；bash/sh 脚本会额外执行 shellcheck 与 shfmt。

### Launchd 定时任务工具

```bash
cd job
./scheduler.sh list                                 # 查看当前以 com.biucing.scripts.job.* 命名的任务
./scheduler.sh create \
    --job-name daily-brew \
    --script ../maintain/formulaes_casks_updater.sh \
    --interval 720                                   # 每 12 小时执行脚本
./scheduler.sh status --job-name daily-brew        # 查看任务加载状态
./scheduler.sh delete --job-name daily-brew        # 卸载并移除任务
```
> 支持 `--dry-run` 预览 plist 内容、`--at HH:MM` 定时以及 `--force` 覆盖，安装态默认把任务日志写入 `~/Library/Logs/macos-scripts/jobs/`。

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

## 🔧 自定义安装清单

- 仓库内运行时，编辑 `setup/brew.conf.sh` 调整 `FORMULAE_*`、`CASKS_*` 数组即可。
- Homebrew 安装态运行时，首次执行 `macos-scripts setup packages` 会自动把默认配置复制到 `~/.config/macos-scripts/brew.conf.sh`，后续编辑该文件即可。
- `macos-scripts setup shell` 与 `macos-scripts setup git` 在安装态下会把备份文件写入 `~/.config/macos-scripts/backups/`，避免把运行产物散落到仓库或安装目录。
- `macos-setup.sh` 会自动加载这些数组并通过新封装的 helper 执行安装。
- 可在运行前通过设置环境变量 `BH_DRY_RUN=true` 做干跑测试（只输出将安装的项目，不实际执行）。

## 🧪 运行验证

- 所有核心脚本均可通过 `zsh -n path/to/script.sh` 做语法检查。
- `lint/lint_shell.sh` 会先按 shebang 执行语法检查，再对 bash/sh 脚本执行 shellcheck 与 shfmt。
- `lib/colors.sh` 的 `log_time_start/log_time_end` 可嵌入到自定义脚本中，统计关键步骤耗时。

## 🤝 贡献指南

欢迎通过 Issue 或 Pull Request 反馈问题与改进建议。在提交前请：

- 阅读遵循 [`CODE_OF_CONDUCT.md`](./.github/CODE_OF_CONDUCT.md)，保持专业、友善的协作氛围。
- 使用对应的 Issue / PR 模板，补充复现信息、测试记录与回滚方案：
    - Issue：`Bug 报告` 与 `功能需求` 模板覆盖常见场景。
    - PR：根据修改范围选择 `setup_script.md`、`maintenance_script.md`、`docs_config_update.md` 或 `multi_scope_change.md`。
- 运行以下校验命令，确认脚本质量：

```bash
./lint/lint_shell.sh            # 确保脚本通过 lint
zsh -n setup/*.sh maintain/*.sh job/*.sh lint/*.sh
bash -n lib/colors.sh setup/git_forge_ssh_setup.sh
```

> 若涉及长耗时任务，建议附带 `log_time_start/_end` 输出截图或日志片段。

## 📜 许可证

本项目采用 MIT 许可证，详见 `LICENSE`。