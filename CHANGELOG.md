---
title: 变更记录
status: current
owner: project-maintainers
updated: 2026-10-17
---

# 变更记录

[English](CHANGELOG.en.md)

此索引汇总历史发布说明，正式发布状态见[版本索引](docs/releases/README.md)。

## 未发布

- 仓库脚本、公共库、测试和 CI 统一使用系统 Zsh，修正交互输入、数组、特殊变量与退出清理的差异。
- 检查入口强制 `#!/bin/zsh` 并执行语法检查；不再依赖 ShellCheck/shfmt，`lint fix` 保留为仅检查的兼容入口。
- 新增 Zsh 迁移回归测试；Homebrew 上游安装脚本仍按其要求使用 Bash。

## 0.5.0

[版本内容](docs/releases/0.5.0/README.md)、[验证与发布清单](docs/releases/0.5.0/validation.md)。

## 0.4.0

[版本内容](docs/releases/0.4.0/README.md)、[验证与发布清单](docs/releases/0.4.0/validation.md)。

## 0.3.0

[版本内容](docs/releases/0.3.0/README.md)、[验证与发布清单](docs/releases/0.3.0/validation.md)。

## 0.2.0

[版本内容](docs/releases/0.2.0/README.md)、[验证与发布清单](docs/releases/0.2.0/validation.md)。

## 0.1.0

[版本内容](docs/releases/0.1.0/README.md)、[验证与发布清单](docs/releases/0.1.0/validation.md)。
