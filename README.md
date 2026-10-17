---
title: macOS 高效自动化脚本库
status: current
owner: project-maintainers
updated: 2026-10-17
---

# macOS 高效自动化脚本库

[English](README.en.md)

面向 macOS 14+ 的 Shell 自动化工具，提供开发环境初始化、Homebrew 维护、macOS 安装器制作和 launchd 定时任务。使用系统 Zsh，统一 CLI 提供彩色日志、耗时统计、幂等检查和 dry-run。当前源码版本见 [VERSION](VERSION)。

## 快速开始

```bash
git clone https://github.com/anzihenry/scripts.git
cd scripts
./bin/macos-scripts --help
./bin/macos-scripts maintain brew --dry-run
```

已有 Homebrew 时可通过 tap 安装：

```bash
brew tap anzihenry/scripts https://github.com/anzihenry/scripts
brew install anzihenry/scripts/macos-scripts
macos-scripts --help
```

全新机器和管道 bootstrap 见[安装指南](docs/guides/installation.md)。

## 文档

- [文档地图](docs/README.md)、[组织约定](docs/documentation.md)
- [使用与维护](docs/guides/using.md)、[定时任务](docs/guides/jobs.md)
- [开发与验证](docs/guides/development.md)、[架构](docs/engineering/architecture.md)
- [项目规划](docs/planning/README.md)、[工作专题](docs/initiatives/README.md)
- [发布指南](docs/guides/releasing.md)、[版本记录](docs/releases/README.md)、[CHANGELOG](CHANGELOG.md)

Agent 协作规则见 [AGENTS.md](AGENTS.md)，贡献者遵循[行为准则](.github/CODE_OF_CONDUCT.md)。

## 许可证

[MIT](LICENSE)。
