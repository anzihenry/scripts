# @COMMAND@

面向 macOS 14+ 系统 Zsh 的最小 CLI 项目。

```sh
zsh bin/@COMMAND@ --help
zsh bin/@COMMAND@ --version
zsh bin/@COMMAND@ hello --dry-run
zsh bin/@COMMAND@ hello
zsh tests/run.sh
```

在 `project.conf` 集中维护项目元数据。业务代码放在 `src/`；`vendor/zsh-kit` 是固定快照，不直接修改。日志默认在 `~/Library/Logs/<项目名>/run.log`；使用配置中环境变量前缀的 `_LOG_DIR` 覆盖。`_CONFIG_DIR` 保留给业务配置，不在帮助、预览或示例命令中创建目录。

公共库负责有界日志、执行器、原子写入和资源锁；应用决定要修改什么、放在哪里。添加动作时显式检查关键命令状态；测试应使用临时 HOME 和替身命令。

升级步骤见 [维护说明](docs/development.md)。不包含自动下载、自动升级、Homebrew、发布或 Bootstrap；这些策略按实际项目需要单独接入。
