---
applyTo: "setup/**/*.sh"
description: "macOS 初始化脚本规范"
---
# Setup 目录脚本指南

## 背景与目标
- 背景：`setup/` 目录用于在全新 macOS 设备上初始化开发环境，包括 Homebrew、终端配置和常用工具安装。
- 目标：
	- 确保脚本在 macOS 14+、Intel 与 Apple Silicon 架构上稳定运行。
	- 提供清晰的日志和耗时统计，便于用户理解进度并排查故障。
	- 复用仓库已有的 `bh_*` 辅助函数，减少重复实现。

## 适用范围
- 文件/目录：`setup/` 子目录下的所有脚本（例如 `homebrew-setup.sh`、`macos-setup.sh`）。
- 关键约束：
	- macOS 版本：支持 macOS 14 及以上。
	- Shell 类型：固定使用 `zsh` 运行。
	- 权限限制：默认不使用 `sudo`；若必须提升权限，需要提前 `warning` 并给出取消选项。

## 代码风格要求
### 头部与基础设置
- Shebang：统一为 `#!/bin/zsh`，保留 `# filepath:` 注释。
- 严格模式：在 shebang 后启用 `set -e` 与 `set -o pipefail`。如需临时放宽（例如捕获安装返回码），需注释原因并在同一上下文恢复。

### 日志与输出
- 统一引入颜色库：`source "$SCRIPT_DIR/../lib/colors.sh"`。
- 记录耗时：对关键步骤使用 `log_time_start` / `log_time_end`，并输出 `print_header`、`info`、`success` 等。
- 输出语言：说明使用中文，命令或变量使用英文。

### 命名规范
- 函数：小写 + 下划线，如 `install_homebrew()`。
- 局部变量：使用 `local`，避免污染全局；全局常量使用大写（如 `BREW_PREFIX`）。

## 功能与结构约束
### 依赖检测
- 在执行关键步骤前使用 `bh_require_commands` 或 `command -v` 检查依赖（如 `curl`、`xcode-select`）。
- 针对缺失依赖提供明确提示与解决方案（示例命令或文档链接）。

### 参数与开关
- 支持 `--dry-run`、`--force` 等开关时，应在日志中说明实际行为（是否执行或仅预览）。
- 幂等保障：在写入配置（如 `~/.zshrc`）前检测是否已有标记，避免重复追加；安装 Homebrew 前检查现有环境。

### 复用组件
- 优先使用 `setup/lib/brew_helpers.sh` 中的 `bh_*` 函数进行安装、重试、统计和 Dry-Run。
- 若需要新的共用逻辑，考虑在 `brew_helpers.sh` 或其他库中抽象。

## 错误处理与提示
- 异常输出使用 `error`，并说明后续操作（重试命令、检查网络、手动执行替代命令）。
- 对网络/下载失败场景提供重试逻辑或 fallback 源（如镜像地址）。
- 长耗时任务（安装工具、下载资源）应在日志中显示总步骤、当前步骤和预计耗时。

## 验证与交付
- 语法检查：`zsh -n setup/<script>.sh`。
- Lint：通过 `./lint/lint_shell.sh`。
- 手动验证：视脚本功能补充，例如验证 Homebrew 是否安装成功、配置文件是否追加正确。

## 推荐 Prompt
- “基于《Setup 目录脚本指南》，在 `setup/foobar-setup.sh` 中实现工具安装流程，支持 ARM/Intel 自适应。”
- “请为 `setup/homebrew-setup.sh` 增加幂等检查和 `bh_*` 重试逻辑，按照指南输出日志。”
- “根据此指南优化脚本的配置写入，避免重复追加 `~/.zshrc` 片段。”

## 维护说明
- 负责人：macOS 初始化脚本维护者。
- 更新频率：每季度或 macOS/Homebrew 重大更新时复查。
- 历史记录：关键变更在 PR 描述中注明，并同步更新 README 或相关文档。
