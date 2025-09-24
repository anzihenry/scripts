# macOS 高效自动化脚本库

本仓库提供了一套功能强大、高度自动化的 Shell 脚本，旨在快速、可靠地配置全新的 macOS 开发环境，并提供日常维护工具。

## ✨ 核心特性

- **一键配置**: `macos-setup.sh` 作为主入口，可一键完成从系统预检、环境配置到软件安装的全过程。
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
    ├── brew.conf.sh        # Homebrew 软件包结构化配置文件 (替代旧的 .txt 文件)
    ├── macos-setup.sh      # [主脚本] macOS 开发环境一站式配置工具
    ├── homebrew-setup.sh   # [独立] Homebrew 安装与镜像配置工具
    ├── ohmyzsh-setup.sh    # [独立] Oh My Zsh 及 Powerlevel10k 主题安装配置工具
    └── git_forge_ssh_setup.sh # [独立] Git 托管服务 SSH 密钥自动生成与配置工具
```

## 🚀 使用方法

### 1. 快速开始 (推荐)

对于一台新的 Mac，推荐直接运行主脚本 `macos-setup.sh` 来完成所有配置。

```bash
# 1. 克隆仓库
git clone https://github.com/anzihenry/scripts.git
cd scripts/setup

# 2. (可选) 自定义要安装的软件
#    编辑 brew.conf.sh 文件，添加或删除你需要的软件包。

# 3. 赋予执行权限并运行主脚本
chmod +x macos-setup.sh
./macos-setup.sh
```

### 2. 运行独立脚本

如果你只需要完成某项特定任务，可以单独运行对应的脚本。所有脚本都位于 `setup/` 或 `maintain/` 目录下。

**示例：单独配置 Oh My Zsh**
```bash
cd scripts/setup
chmod +x ohmyzsh-setup.sh
./ohmyzsh-setup.sh
```

**示例：更新所有 Homebrew 软件**
```bash
cd scripts/maintain
chmod +x formulaes_casks_updater.sh
./formulaes_casks_updater.sh
```

### 3. 配置 SSH 密钥

`git_forge_ssh_setup.sh` 脚本可以帮你为不同的 Git 平台（如 GitHub, GitLab）生成和配置独立的 SSH 密钥。

```bash
cd scripts/setup
chmod +x git_forge_ssh_setup.sh

# 为 github.com 生成一个个人用途的密钥
./git_forge_ssh_setup.sh -d github.com -t personal

# 为公司内部的 gitlab.company.com 生成一个工作用途的密钥
./git_forge_ssh_setup.sh -d gitlab.company.com -t work
```
脚本会自动处理密钥生成、`~/.ssh/config` 文件更新、公钥上传（仅 GitHub）和连接测试。

## 🔧 自定义配置

自定义开发环境的核心是修改 `setup/brew.conf.sh` 文件。你可以按类别添加、修改或删除 `FORMULAE_*` 和 `CASKS_*` 数组中的软件包名称。主脚本在运行时会自动读取这些配置进行安装。

## 🤝 贡献

欢迎通过提交 Pull Request 来改进这些脚本。如果你有任何问题或建议，请创建一个 Issue。

## 📜 许可证

这个项目使用 MIT 许可证。详情请参阅 `LICENSE` 文件。