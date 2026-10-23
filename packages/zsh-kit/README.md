# zsh-kit 0.2.0（待发布）

面向 macOS 14+ 系统 Zsh 的离线公共组件，MIT 许可。直接 source `lib/zsh-kit.sh` 或单个模块。source 不创建文件、不设置调用方选项/trap，重复加载保留状态。入口脚本自行开启 `set -euo pipefail`。

| 模块 | 公开接口（位置参数） |
| --- | --- |
| console | `sk_log level message`；`sk_info/warning/error/success message`；`sk_time_start key [message]`、`sk_time_end key [message] [level]` |
| command_runtime | `sk_command_preview command args...`；`sk_run_command command args...`；`sk_run_logged_command description command args...`；`sk_run_timed_command_or_fail key start success failure detail command args...` |
| workflow | `sk_run_stages label function ...`，失败停止并保留动作退出码 |
| resource_lock | `sk_resource_lock_acquire resource`；`sk_with_resource_lock resource command args...`；`sk_resource_locks_release_owned` |
| config_writer | `sk_write_managed_file path content [dry_run] [mode]`；`sk_write_managed_block path section manager content [dry_run] [marker_style] [validate_zsh]`；`sk_set_ini_values path section key value ...`；`sk_set_ini_value path section key value` |
| logging | `sk_append_log path data`；`sk_start_capture path [merged|separate]`；`sk_finish_capture` |

其他函数为实现细节，不保证兼容。日志目录由调用方创建并传入；库不选择用户目录。`SK_LOG_MAX_BYTES` 默认 5242880、`SK_LOG_BACKUPS` 默认 5、`SK_LOG_RETENTION_DAYS` 默认 30；在写入/启动捕获时验证。`SK_DRY_RUN=true` 仅预览执行器命令；文件写入器使用显式 dry_run 参数。`SK_LOCK_TIMEOUT` 默认 10 秒。`SK_RECOVERY_MESSAGE` 可补充阶段失败提示。`SK_LOG_SINK` 可指定接收 level/message 的日志函数。

非捕获状态下诊断写 stderr，预览/数据写 stdout；动作错误保留原码。库不替调用方开启 errexit，动作必须显式传播内部失败。捕获开始会重定向当前进程 stdout/stderr，并安装 `zshexit_functions` 排空钩子；结束恢复描述符且保持进入结束函数前的退出码。业务在退出前输出最终摘要；记录器失败只报告日志不完整，不覆盖业务状态。不支持嵌套捕获。默认 `merged` 保留旧行为：两个通道合并后输出到原 stdout 并记日志。新项目模板显式使用 `separate`，两个通道分别回到原 stdout/stderr，均记录日志；不同通道间不保证全局到达顺序，日志故障每个通道各提示一次。

写入器使用同目录候选文件和 rename；无变化不重写，保留普通权限；不承诺 ACL/扩展属性及多文件原子事务。有效符号链接解析到真实文件后加锁；失效链接拒绝。Shell 块语法校验由调用方显式开启。

锁协议 v1 固定目录 `/tmp/macos-scripts-locks-$EUID`，保留历史名称以协调旧调用方；不按项目名或 TMPDIR 隔离。资源绝对路径规范化后 SHA-256；锁文件永久保留，内核 fcntl 锁随进程退出释放。同步重入可继承父锁；持锁事务内禁止并行派生写入任务。调用方退出或调用 release 释放自己的锁，不释放父事务锁。

依赖均来自系统：Zsh（zsh/system）、awk、sed、stat、shasum、mktemp、cmp、chmod、mv、cp、mkdir、rm、date、tail、mkfifo。没有 Homebrew、Python、网络和业务目录运行依赖。版本与应用 VERSION 分开；0.x 次版本允许审阅后迁移，补丁版本保持公开 API。

## 离线分发与升级

仓库工具 `tools/vendor_zsh_kit.sh` 支持 `--sync SOURCE DEST`、`--diff SOURCE DEST` 和 `--check DEST`。SOURCE 是已获取的本地组件目录，DEST 通常为新项目的 `vendor/zsh-kit`。先 diff 审阅（存在差异返回 1），再 sync，最后执行调用方测试。运行应用时不需要该工具、Git 或网络。

清单 `.zsh-kit-manifest` 记录组件版本、源 URL、源 HEAD、源是否有未提交改动和每个 payload 文件的 SHA-256。dirty=true 表示快照包含未提交内容，revision 不能单独复现它；发布应从干净提交生成。非 Git 来源明确记录 unversioned/local。摘要用于检测本地改动，不是发布者身份签名。检查工具也拒绝符号链接及非普通文件；不覆盖未知目录或已修改的 vendor。需要修改公共库时回到源包修改并升级，不直接编辑 vendor。

同步先在同文件系统准备并校验候选目录，再替换；失败恢复旧副本。升级期间不要运行正在使用该 vendor 的进程。同步完成后 `source` 新库须在新进程中执行，不支持热升级。删除源仓库后 vendored payload 仍可运行及测试。

独立验证入口为 `zsh tests/contract.sh`（在包目录运行），仓库完整命令见 [开发指南](../../docs/guides/development.md)。复制包后该仓库文档链接可能不可用，独立测试不依赖它。

参数契约：非法参数返回 2，且在文件、目录、日志、锁操作之前拒绝。布尔值仅接受字面量 `true`/`false`；省略才使用默认值，显式空值不等于省略。路径必须非空；配置块名称为非空单行文本；INI 节/键不能包含结构分隔符，值不能包含换行；权限接受三或四位八进制数字（空字符串表示保留/默认）。日志策略为有界正整数，锁等待时间为 0–9999 秒。执行器仍保留被调用命令的原始退出码。

## API 边界

`API.txt` 是公开函数清单，契约测试比较实际加载后的函数集合；其余函数均以 `_sk_` 开头，仅供组件内部或故障注入测试使用。应用和模板不调用私有函数。新增公开函数必须同步清单、接口文档和消费者测试。

高级接口 `sk_commit_config_candidate target candidate [mode]` 提交调用方构造并验证的同目录候选普通文件；成功后候选文件被消费。调用方必须在读取原文件和准备候选文件之前获取 target 资源锁，并保持同步调用链；接口本身还会保护提交，但无法修正加锁前根据陈旧内容生成的候选文件。失败前后候选文件是否仍存在不属于保证，调用方应使用自己的清理 trap。

兼容测试包含冻结的消费者场景，在旧 vendored 包和当前源包运行同一份代码，比较配置内容与退出码。额外测试覆盖捕获期间重复加载、分离输出通道和公开清单漂移；不能只通过增加一个无关函数来证明兼容性。
