# Copilot Agents 指南（实验特性）

> 本文件为 VS Code `AGENTS.md`，需启用 `chat.useAgentsMdFile` 设置后生效。用于指导 Copilot agent 模式在仓库中的协作方式与安全边界。

## 工作区背景
- 仓库类型：macOS 自动化 Shell 脚本，覆盖初始化 (`setup/`)、维护 (`maintain/`) 与工具 (`lint/`, `lib/`).
- 语言约束：主要为 `bash` (macOS 3.x) 与 `zsh`，需兼容 macOS 14+ 自带工具，不依赖 GNU 特性。
- 配置来源：
  - `/.github/copilot-instructions.md`：通用规范。
  - `/.github/instructions/*.instructions.md`：目录/任务专项规范。
  - 建议在执行前通过 `#instructions` 或自动绑定的文件加载对应上下文。

## 角色与分工
| Agent | 职责 | 首选上下文 |
|-------|------|------------|
| Setup Agent | 初始化流程、Homebrew/环境配置 | `setup/**/*.sh`、`setup/lib/brew_helpers.sh` 指南 |
| Maintain Agent | 日常维护、批量更新、安装器制作 | `maintain/**/*.sh` 指南、`brew_update_errors.log` |
| QA Helper | Lint、脚本自检、文档同步 | `lint/lint_shell.sh`、README、贡献指南 |

> 如无特定划分，可由单个 agent 串行执行任务，但仍需遵循下文的流程与安全守则。

## 工作流程
1. **启动前准备**
   - 使用 `#codebase` 或 `#file` 添加关键脚本。
   - 根据任务类型主动引用相应的 `.instructions.md`（例如 `#instructions shell-general`）。
   - 调用 `#changes` 查看最新 diff，确认上下文是否干净。
2. **计划阶段**
   - 生成三段式计划：目标、步骤、风险。必要时将计划写入 Todo（需启用 `chat.todoListTool.enabled`）。
   - 对涉及多个目录的任务，明确委派顺序（先 Setup Agent，再 Maintain Agent）。
3. **执行阶段**
   - 优先使用编辑工具（`#editor`, `#edits`），仅在必要时运行终端命令，并注明目的。
   - 对潜在破坏性命令（如 `brew upgrade`, `diskutil`）先 dry-run 或征得确认；禁止直接执行 `sudo`。
4. **验证阶段**
   - 自动运行可用的 lint/语法检查任务（如 `./lint/lint_shell.sh`, `zsh -n`）。
   - 若任务涉及 Homebrew，建议读取/写入 `brew_update_errors.log` 以汇总失败项。
5. **总结阶段**
   - 输出变更摘要、验证结果、后续建议（与 PR 模板保持一致）。
   - 引导用户审阅 diff 并决定是否提交。

## 工具与命令策略
- **首选工具**：`codebase`、`edits`、`changes`, `problems`, `terminal`（受限）。
- **MCP/扩展工具**：仅在项目批准后使用；如需外部依赖，请说明来源与安全影响。
- **终端命令白名单**：`git status`, `ls`, `cat`, `zsh -n`, `./lint/lint_shell.sh`. 其他命令需逐条确认。
- **任务集成**：若存在 `tasks.json`，可运行 `npm run lint` 等任务，执行前需说明原因。

## 安全与合规
- 保持 `chat.checkpoints.enabled` 开启，每个重大步骤前后创建 checkpoint，便于回滚。
- 禁止修改 `.env`、密钥、用户主目录配置，除非指令明确授权。
- 任何写入 `~/` 配置的操作必须使用带标记的插入片段，避免重复。
- 对长耗时操作输出进度与耗时信息，提醒用户保持终端活跃。

## 沟通与交接
- 在多 agent 协作时，将阶段成果写入 Todo 或总结，明确下一位 agent 需要的输入。
- 若任务被中断，使用总结说明当前状态、剩余风险与未完成步骤。
- 鼓励在总结中引用相关指南链接（如 `.github/instructions/maintain-scripts.instructions.md`），便于后续查阅。

## 维护与反馈
- 负责人：脚本仓库维护者。
- 检视频率：每季度或 VS Code agent 功能有重大更新时复查。
- 反馈渠道：在 PR/Issue 中记录 agent 运行中的成功案例与问题，便于持续优化。
