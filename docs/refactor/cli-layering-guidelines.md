# CLI 分层约定

## 目标

为 `bin/macos-scripts` 及其 `bin/lib/` 下的 CLI 代码建立稳定分层，避免后续迭代重新回到“入口、参数校验、转发拼装、业务分发混写在一起”的状态。

本约定关注的是 **CLI 装配层**，不覆盖 `setup/`、`maintain/`、`job/` 下业务脚本内部实现。

## 当前分层

当前 CLI 建议维持以下装配顺序：

1. 入口层：`bin/macos-scripts`
2. 帮助层：`bin/lib/help*.sh`
3. 共享运行时层：`bin/lib/cli_runtime.sh`
4. 参数转发层：`bin/lib/cli_forward_args.sh`
5. 参数校验层：`bin/lib/validators*.sh`
6. 分发层：`bin/lib/cli_dispatch*.sh`

## 入口层

文件：

- `bin/macos-scripts`

职责：

- 初始化 CLI 运行环境
- 导出仓库根目录、日志目录、配置目录
- 按固定顺序 source 各层模块
- 调用 `main "$@"`

不要做的事：

- 不写命令分支逻辑
- 不写参数校验
- 不写 help 文案
- 不写 forwarding glue

判断标准：

- 入口文件应保持“可一眼看完”
- 入口层的改动，大多数应是 source 顺序或环境变量初始化相关

## 帮助层

文件：

- `bin/lib/help.sh`
- `bin/lib/help_router.sh`
- `bin/lib/help_main.sh`
- `bin/lib/help_setup.sh`
- `bin/lib/help_maintain.sh`
- `bin/lib/help_release.sh`
- `bin/lib/help_job.sh`
- `bin/lib/help_lint.sh`

职责：

- 维护帮助文案
- 维护 `help <topic>` 的主题路由

约定：

- 文案文件按领域拆分，不把全部帮助文本重新塞回单文件
- `help_router.sh` 只做主题路由，不承载文案正文
- dispatch 层遇到 `--help` 时，只调用对应 help 函数，不拼接输出文本

不要做的事：

- 不做参数合法性判断
- 不做命令执行
- 不读取业务脚本状态

## 共享运行时层

文件：

- `bin/lib/cli_runtime.sh`

职责：

- 提供脚本运行 helper，例如 `run_zsh_script`、`run_bash_script`
- 提供共享分发骨架，例如 `dispatch_validated_action`
- 提供通用 CLI 错误输出 helper，例如 `usage_error`、`command_error`
- 提供纯通用的小工具，例如 `has_help_flag`

约定：

- 这里只放 **跨领域可复用** 的 helper
- helper 应保持“无领域知识”或“极弱领域知识”

不要做的事：

- 不放 setup/release/job 专属的 forwarding 细节
- 不放大段业务条件分支
- 不把单个领域的一次性封装硬塞进 runtime

判断标准：

- 如果一个 helper 只在单个领域出现，优先放在对应 dispatch 文件或领域 helper 文件
- 如果一个 helper 需要知道具体 help 文案、具体 tag 规则、具体默认参数，多半不该放 runtime

## 参数转发层

文件：

- `bin/lib/cli_forward_args.sh`

职责：

- 维护 “CLI 参数 -> 底层脚本参数” 的补全与转发拼装逻辑

当前典型场景：

- `setup github` 自动补齐 `--domain github.com --type personal`
- `release publish|verify` 自动补齐标准化 tag、默认 notes 文件、模式标志

约定：

- forwarding glue 单独放这一层，不回流到 dispatch 文件
- 对外优先暴露 `load_*_forwarded_args` 这类装配友好的接口

不要做的事：

- 不直接执行底层脚本
- 不承担参数合法性校验
- 不输出帮助文案

## 参数校验层

文件：

- `bin/lib/validators.sh`
- `bin/lib/validators_setup.sh`
- `bin/lib/validators_maintain.sh`
- `bin/lib/validators_job.sh`
- `bin/lib/validators_release.sh`

职责：

- 做参数合法性校验
- 在失败时通过 `usage_error` 输出统一错误与帮助

约定：

- validator 按领域拆分
- validator 专注“参数是否可接受”，不负责真正执行命令
- 与底层业务脚本的默认值拼装分开维护

不要做的事：

- 不直接调用 `run_*_script`
- 不写命令路由
- 不混入 forwarding 补齐逻辑

判断标准：

- 如果某段逻辑只是检查“是否缺少参数 / 参数是否越界 / 是否允许某个 flag”，应优先进入 validator

## 分发层

文件：

- `bin/lib/cli_dispatch.sh`
- `bin/lib/cli_dispatch_setup.sh`
- `bin/lib/cli_dispatch_maintain.sh`
- `bin/lib/cli_dispatch_release.sh`
- `bin/lib/cli_dispatch_job.sh`
- `bin/lib/cli_dispatch_lint.sh`

职责：

- 做命令路由
- 组织 `help -> validate -> forward -> run`
- 维持每个一级命令的装配边界

约定：

- `cli_dispatch.sh` 只做一级命令总分发
- 各领域 dispatch 文件只维护本领域路由
- dispatch 层优先表现为“编排器”，而不是实现层

允许存在的局部 helper：

- 仅在本领域复用、且能明显压平重复代码的 helper
- 例如 setup 的无参数命令分发 helper

不要做的事：

- 不把大段 validator 逻辑重新写回 dispatch
- 不把 forwarding 细节重新写回 dispatch
- 不在 dispatch 中堆叠复杂业务条件

判断标准：

- 如果某个分支超过 “help / validate / forward / run” 这一骨架很多，就应考虑下沉

## 命名约定

建议保持以下口径：

- `handle_*`
  - 命令或子命令分发入口
- `validate_*`
  - 参数校验函数
- `load_*_forwarded_args`
  - 供 dispatch 使用的转发参数装配入口
- `build_*_forwarded_args`
  - 返回完整参数列表的底层构造函数
- `dispatch_*`
  - 局部命令分发 helper，强调“编排层辅助”
- `run_*`
  - 运行底层脚本或共享 runner

避免的情况：

- 同一类 helper 同时混用 `build / make / collect / prepare` 而没有明确分工
- dispatch 层 helper 起成 runtime 风格名字，或反过来

## 改动准则

后续提交如果涉及 CLI 层，优先按以下顺序判断落点：

1. 是帮助文案或帮助主题路由吗？
   - 放 `help*.sh`
2. 是参数合法性校验吗？
   - 放 `validators*.sh`
3. 是 CLI 到底层脚本的参数补齐与转发吗？
   - 放 `cli_forward_args.sh`
4. 是跨领域共享的运行/错误/通用骨架吗？
   - 放 `cli_runtime.sh`
5. 是某个命令的路由与编排吗？
   - 放 `cli_dispatch*.sh`

如果一个改动同时跨越多层，应优先拆成小提交，避免把“分层整理”和“功能变更”混在一起。

## 回归要求

CLI 层改动后，至少运行以下检查：

```bash
bash tests/syntax_guard.sh
bash tests/smoke_cli.sh
zsh tests/cli_dispatch_guard.sh
zsh tests/cli_validators_guard.sh
```

如果改动涉及 release、setup、job、maintain 的内部装配逻辑，按需补充对应 guard。

## 何时停止继续抽象

满足以下任一情况时，应优先停止抽象、转向文档或测试：

- helper 只减少 2 到 3 行重复，但引入额外跳转成本
- helper 开始同时处理多个领域的特殊分支
- dispatch 文件已经能稳定表现为薄编排层
- 新抽象无法明显提升测试性或可读性

本项目当前的目标不是“抽象最多”，而是 **让 CLI 分层稳定、可读、可测、可继续演进**。
