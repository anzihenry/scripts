# file-organizer

从 `templates/zsh-cli` 生成的独立示例，可复制整个目录到仓库之外运行。面向 macOS 14+ 系统 Zsh，无需安装依赖或访问网络。

```sh
zsh bin/file-organizer --help
zsh bin/file-organizer organize /path/to/test-directory --dry-run
zsh bin/file-organizer organize /path/to/test-directory
zsh tests/run.sh
```

只扫描给定目录顶层的普通文件，将 txt/md/pdf 移到 `organized/documents`、png/jpg/jpeg 移到 `organized/images`，其余移到 `organized/other`。忽略目录、隐藏文件和符号链接，不递归整理。日志默认在 `~/Library/Logs/file-organizer/run.log`，可用 `FILE_ORGANIZER_LOG_DIR` 覆盖；日志不能放在待整理目录内。

预览不创建目录、日志或锁。实际执行在目录资源锁内重新扫描，先检查全部目标冲突，再逐个移动；已有目标一律拒绝，不覆盖。已移动文件不再参与下次扫描，因此可重复执行。中途失败时保留已完成的移动，输出完成数量；修复原因后重跑即可继续。它不提供整批回滚，也不能阻止不遵守资源锁的其他程序操作同一目录。

测试只操作临时目录，覆盖空格路径、预览、重复执行、冲突不覆盖、命令故障后重跑、符号链接目标保护。`src/organize.sh` 是业务模块；`src/main.sh` 负责路由；`project.conf` 集中配置应用与组件版本；vendor 为固定的 0.1.0 快照。

离线升级见 [维护说明](docs/development.md)。仓库 `tests/reuse_acceptance_guard.sh` 额外将整个示例复制到独立目录，在仅系统 PATH 下运行，并用临时 0.1.1 **模拟补丁**演练 diff、sync 和回归；该补丁不是已发布版本。升级前后业务模块摘要必须一致，删除补丁源后仍能通过测试。
