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

# 授权脚本可执行（按需操作）
chmod +x setup/*.sh maintain/*.sh lint/*.sh
```

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
./lint/lint_shell.sh           # 仅检查
./lint/lint_shell.sh --fix     # 自动使用 shfmt 格式化
```
> 依赖 `shellcheck` 与 `shfmt`（可通过 Homebrew 安装）。

### Homebrew 日常维护

```bash
cd maintain
./formulaes_casks_updater.sh   # 更新所有 Formulae/Cask，失败项写入 brew_update_errors.log
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
> 脚本为关键命令记录耗时，并使用锁避免并发冲突。

## 🔧 自定义安装清单

- 编辑 `setup/brew.conf.sh` 调整 `FORMULAE_*`、`CASKS_*` 数组即可。
- `macos-setup.sh` 会自动加载这些数组并通过新封装的 helper 执行安装。
- 可在运行前通过设置环境变量 `BH_DRY_RUN=true` 做干跑测试（只输出将安装的项目，不实际执行）。

## 🧪 运行验证

- 所有核心脚本均可通过 `zsh -n path/to/script.sh` 做语法检查。
- `lint/lint_shell.sh` 用于持续保持脚本风格与质量。
- `lib/colors.sh` 的 `log_time_start/log_time_end` 可嵌入到自定义脚本中，统计关键步骤耗时。

## 🤝 贡献指南

欢迎通过 Issue 或 Pull Request 反馈问题与改进建议。提交前建议运行：

```bash
./lint/lint_shell.sh            # 确保脚本通过 lint
zsh -n setup/*.sh maintain/*.sh # 快速语法检查
```

## 📜 许可证

本项目采用 MIT 许可证，详见 `LICENSE`。