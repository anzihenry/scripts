# GitHub Copilot 工作区指导

> 面向仓库内所有 Copilot 对话与 agent 会话，请结合 `AGENTS.md` 与 `.github/instructions/*.instructions.md` 使用。

## 背景与目标
- 背景：本仓库收录 macOS 14+ 自动化脚本，覆盖初始化 (`setup/`)、维护 (`maintain/`) 与工具 (`lint/`, `lib/`) 场景。
- 目标：
	- 生成符合 Bash 3.x / Zsh 语法、可在系统自带工具上运行的脚本。
	- 优先保证幂等、安全与可回滚，必要时提供 `--force`、`--dry-run` 等开关。
	- 默认输出彩色日志并记录关键步骤耗时，便于运维与排错。

## 适用范围
- 文件/目录：整个工作区的 Shell、文档与辅助脚本；目录级规则由对应 `*.instructions.md` 细化。
- 关键约束：
	- macOS 版本：支持 Sonoma (14) 及以上，避免依赖 GNU-only 工具。
	- Shell 类型：`setup/` 使用 `zsh`；`maintain/` 当前以既有 shebang 为准（仓库内核心脚本目前为 `zsh`）；其余按既有 shebang。
	- 权限：默认拒绝 `sudo`，如需使用须在日志中明确提示风险与确认步骤。

## 代码风格要求
### 头部与基础设置
- 保留并更新 shebang 与 `# filepath:` 注释。
- 根据 Shell 类型启用 `set -euo pipefail` 或等效的严格模式，临时关闭需说明原因并及时恢复。

### 日志与输出
- 统一引入 `lib/colors.sh`，使用 `print_header`、`info`、`success`、`warning`、`error`、`highlight`、`log_time_start`/`_end` 等函数。
- 输出以中文描述为主，命令/文件名保持英文。

### 命名规范
- 函数使用小写+下划线，局部变量加 `local`，常量大写或具有明显前缀。
- 避免未使用变量、魔法字符串，必要时抽离为常量或配置项。

## 功能与结构约束
### 依赖与安全
- 运行前通过 `command -v` 或库函数校验依赖；缺失时提示安装方式。
- 在执行网络、磁盘或系统修改操作前检查当前状态，并提供幂等处理分支。

### 复用组件
- Homebrew 逻辑优先调用 `setup/lib/brew_helpers.sh` 的 `bh_*` 函数。
- 日志、计时、错误处理遵循公共库实现，避免重复造轮子。

## 错误处理与提示
- 捕获失败时调用 `error` 并给出下一步行动（重试、检查网络、手动命令等）。
- 长耗时任务记录进度/耗时，必要时写入 `brew_update_errors.log` 等统一日志。

## 验证与交付
- 测试命令清单以 `README.md`「运行验证」为**唯一权威源**，本指南不再罗列。
- 按改动范围选择层级（语法 → lint → smoke → guard → E2E），改完至少跑一遍 `./tests/syntax_guard.sh` 与对应层级。
- 涉及跨流程或发布前改动时，务必补跑 `bash tests/e2e/run_all.sh`（进程级沙箱 E2E）。
- 在 PR/总结中列出验证命令与结果，保持与 `AGENTS.md` 要求一致。

## 推荐 Prompt
- “根据《GitHub Copilot 工作区指导》与 `setup` 指南，为 `setup/new-script.sh` 生成初始化脚本，包含幂等检查与日志。”
- “请在遵循工作区指南的前提下，为 `maintain/tool.sh` 增加 `--dry-run` 选项并记录耗时。”
- “结合本指南和 `shell-general.instructions.md`，重构以下函数以复用 `bh_*` 辅助函数。”

## 维护说明
- 负责人：脚本仓库维护者。
- 更新频率：每季度或 macOS/Copilot 功能重大更新时复查。
- 关联文档：`AGENTS.md`、`.github/instructions/*.instructions.md`、`README.md`。
