# Job 工具

`job/` 目录提供围绕 macOS `launchd` 的定时任务管理脚本，方便为仓库内其他可执行脚本创建周期性或定时运行的任务。

## 快速开始

- `scheduler.sh create --job-name daily-brew --script ./maintain/formulaes_casks_updater.sh --interval 7200`
- `scheduler.sh create --job-name morning-macos --script ./maintain/macos_sys_usb_maker.sh --at 09:00`
- `scheduler.sh status --job-name daily-brew`
- `scheduler.sh disable --job-name daily-brew`
- `scheduler.sh delete --job-name daily-brew`

所有命令均支持 `--dry-run` 查看计划执行的操作。更多选项请运行 `scheduler.sh --help`。
