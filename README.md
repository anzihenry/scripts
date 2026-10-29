---
title: macOS 高效自动化脚本库
status: current
owner: project-maintainers
updated: 2026-10-17
---

# macOS 高效自动化脚本库

[English](README.en.md)

面向 macOS 14+ 的 Shell 自动化工具，提供开发环境初始化、Homebrew 维护、macOS 安装器制作。使用系统 Zsh，统一 CLI 提供彩色日志、耗时统计、幂等检查和 dry-run。当前源码版本见 [VERSION](VERSION)。

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
- [使用与维护](docs/guides/using.md)
- [开发与验证](docs/guides/development.md)、[架构](docs/engineering/architecture.md)
- [项目规划](docs/planning/README.md)、[工作专题](docs/initiatives/README.md)
- [发布指南](docs/guides/releasing.md)、[版本记录](docs/releases/README.md)、[CHANGELOG](CHANGELOG.md)

Agent 协作规则见 [AGENTS.md](AGENTS.md)，贡献者遵循[行为准则](.github/CODE_OF_CONDUCT.md)。

## 许可证

[MIT](LICENSE)。

## 创建新的 Zsh 项目

公共库位于 [`packages/zsh-kit`](packages/zsh-kit/README.md)，模板位于 `templates/zsh-cli`。生成一个独立项目：

```sh
zsh tools/create_zsh_project.sh --name my-tool --description "我的 macOS 工具" /path/to/new-project
```

生成器拒绝覆盖已有目录，包含固定版本 vendor、CLI、元数据、测试和 CI；无需原仓库即可运行。接口与分发规则见 [实施约定](docs/engineering/reuse-plan.md)，验证见 [开发指南](docs/guides/development.md)。

[`examples/file-organizer`](examples/file-organizer/README.md) 提供从模板生成的独立文件整理示例，展示预览、幂等、冲突保护和失败重跑，以及离线升级验收。

公共组件当前为 zsh-kit 0.2.1（待发布）；独立版本与离线交付规则见 [组件发布指南](docs/guides/releasing-zsh-kit.md)。
