# GitHub Copilot 工作区指导

- 这是一个面向 macOS 的 Shell 自动化脚本仓库，优先编写 `bash` 或 `zsh` 脚本，且需兼容 macOS 14 及以上版本的系统自带工具。
- 保持脚本**幂等**，在执行破坏性操作之前检测状态或提供 `--force` 等显式开关。
- 默认使用仓库提供的日志工具 (`lib/colors.sh` 中的 `print_header`/`info`/`success`/`warning`/`error` 等函数) 输出彩色日志，并在关键步骤记录耗时或统计信息。
- 处理 Homebrew 相关逻辑时，优先复用 `setup/lib/brew_helpers.sh`、遵循现有的重试、统计与错误处理模式。
- 生成或修改脚本时，应保留脚本顶部的 shebang 与路径注释，必要时补充 `set -euo pipefail` 或显式的错误处理分支。
- 在 README 或文档中保持中文说明为主，可在需要时补充英文关键字，确保命令示例可直接复制执行。
- 设计函数接口时保证可测试性：返回状态码、避免全局变量泄露，并通过 `command -v` 等方式检测依赖。
- 所有新脚本都应该经过 `./lint/lint_shell.sh` 与 `zsh -n` 的语法检查，必要时在说明文档中提醒执行者。
