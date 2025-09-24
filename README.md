# macOS 高效自动化脚本库

本仓库提供了一套功能强大、高度自动化的 Shell 脚本，旨在快速、可靠地配置全新的 macOS 开发环境，并提供日常维护工具。

## ✨ 核心特性

- **分步式一键配置**: 提供清晰的脚本执行顺序，从终端美化、包管理器安装到开发环境配置，一气呵成。
- **幂等性设计**: 所有脚本均可安全地重复执行，无需担心重复配置或产生副作用。
- **国内网络优化**: 自动为 Homebrew、Git、npm、pip、gem 等工具配置国内镜像源（中科大、Gitee、腾讯云等），大幅提升下载和安装速度。
- **模块化与独立性**: 每个安装脚本（如 `homebrew-setup.sh`, `ohmyzsh-setup.sh`）均可独立运行，满足特定的配置需求。
- **结构化配置**: 通过 `brew.conf.sh` 文件，可以清晰、分类地管理需要通过 Homebrew 安装的软件包和应用。
- **统一的彩色日志**: 所有脚本均使用统一的日志库 `colors.sh`，输出信息清晰、美观，易于追踪执行过程。

## 📂 目录结构

```
.
├── README.md               # 本说明文档
├── LICENSE                 # MIT 许可证
├── lib/
│   └── colors.sh           # 通用彩色日志输出库
├── maintain/
│   └── formulaes_casks_updater.sh # Homebrew 软件包批量更新与维护工具
└── setup/
    ├── brew.conf.sh            # Homebrew 软件包结构化配置文件
    ├── macos-setup.sh          # [步骤3] macOS 开发环境与软件批量安装
    ├── homebrew-setup.sh       # [步骤2] Homebrew 安装与镜像配置
    ├── ohmyzsh-setup.sh        # [步骤1] Oh My Zsh 及 Powerlevel10k 主题安装
    └── git_forge_ssh_setup.sh  # [可选] Git 托管服务 SSH 密钥自动生成与配置
```

## 🚀 使用方法

### 快速开始：在新 Mac 上分步配置 (推荐)

对于一台新的 Mac，推荐按照以下顺序执行脚本，以完成一个完整、漂亮的开发环境搭建。

```bash
# 1. 克隆仓库到本地
git clone https://github.com/anzihenry/scripts.git
cd scripts/setup

# 2. 赋予所有安装脚本执行权限
chmod +x ./*.sh
```

#### 步骤 1: 配置终端环境 (Oh My Zsh)
此脚本将安装 Oh My Zsh、Powerlevel10k 主题及推荐字体，美化你的终端。
```bash
./ohmyzsh-setup.sh
```
> 执行完毕后，请按照提示设置终端字体，并**完全重启终端**以加载新环境。

#### 步骤 2: 安装包管理器 (Homebrew)
此脚本将安装 Homebrew 并自动配置国内镜像源。
```bash
./homebrew-setup.sh
```
> 执行完毕后，强烈推荐**完全重启终端**以加载新环境。

#### 步骤 3: 安装开发环境和应用
此脚本是核心步骤，它会根据 `brew.conf.sh` 的配置，批量安装所有开发工具和图形化应用。
```bash
# (可选) 在执行前，编辑 brew.conf.sh 文件，自定义你需要的软件包。
./macos-setup.sh
```

#### 步骤 4 (可选): 配置 Git SSH 密钥
此脚本可以帮你为不同的 Git 平台（如 GitHub, GitLab）生成和配置独立的 SSH 密钥。
```bash
# 为 github.com 生成一个个人用途的密钥
./git_forge_ssh_setup.sh -d github.com -t personal

# 为公司内部的 gitlab.company.com 生成一个工作用途的密钥
./git_forge_ssh_setup.sh -d gitlab.company.com -t work
```

### 日常维护

**更新所有 Homebrew 软件**
```bash
cd ../maintain
chmod +x formulaes_casks_updater.sh
./formulaes_casks_updater.sh
```

## 🔧 自定义配置

自定义开发环境的核心是修改 `setup/brew.conf.sh` 文件。你可以按类别添加、修改或删除 `FORMULAE_*` 和 `CASKS_*` 数组中的软件包名称。`macos-setup.sh` 脚本在运行时会自动读取这些配置进行安装。

## 🤝 贡献

欢迎通过提交 Pull Request 来改进这些脚本。如果你有任何问题或建议，请创建一个 Issue。

## 📜 许可证

这个项目使用 MIT 许可证。详情请参阅 `LICENSE` 文件。