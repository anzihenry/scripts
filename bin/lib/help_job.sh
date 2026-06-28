#!/bin/zsh
# filepath: bin/lib/help_job.sh

print_job_action_help() {
  cat <<'EOF'
用法:
  macos-scripts job list
  macos-scripts job status --job-name <name>
  macos-scripts job create --job-name <name> --script <path> [调度参数]
  macos-scripts job enable --job-name <name>
  macos-scripts job disable --job-name <name>
  macos-scripts job delete --job-name <name>

常用参数:
  --job-name <名称>
  --script <路径>
  --interval <分钟>
  --at <HH:MM>
  --weekday <0-6>
  --keepalive
  --working-dir <路径>
  --stdout <文件>
  --stderr <文件>
  --no-load
  --disabled
  --force
  --dry-run
  -h, --help
EOF
}

print_job_list_help() {
  cat <<'EOF'
用法:
  macos-scripts job list

说明:
  列出当前用户下由 macos-scripts 管理的 launchd 任务。

参数:
  当前不接受额外参数。
EOF
}

print_job_status_help() {
  cat <<'EOF'
用法:
  macos-scripts job status --job-name <name>

说明:
  查看指定任务的当前加载状态和 launchctl 输出。

选项:
  --job-name <name>   任务名称，仅支持字母、数字、点、下划线和短横
  -h, --help          显示帮助
EOF
}

print_job_create_help() {
  cat <<'EOF'
用法:
  macos-scripts job create --job-name <name> --script <path> [调度参数] [-- 脚本参数...]

说明:
  创建或更新 launchd 任务，并默认加载。

必填选项:
  --job-name <name>      任务名称，仅支持字母、数字、点、下划线和短横
  --script <path>        目标脚本路径

调度参数:
  --interval <分钟>      循环执行间隔，正整数
  --at <HH:MM>           每日执行时间，24 小时制
  --weekday <0-6>        配合 --at 使用，0 表示周日

执行选项:
  --keepalive            异常退出后自动重启
  --working-dir <path>   WorkingDirectory，默认仓库根目录
  --stdout <file>        标准输出日志路径
  --stderr <file>        标准错误日志路径
  --no-load              创建后不立即加载
  --disabled             创建时标记为 Disabled
  --force                覆盖同名任务并备份旧文件
  --dry-run              仅预览将执行的操作
  -h, --help             显示帮助

说明:
  必须提供 --interval 或 --at 至少一个。
  如需向目标脚本透传参数，请在参数列表末尾使用 -- 分隔。
EOF
}

print_job_enable_help() {
  cat <<'EOF'
用法:
  macos-scripts job enable --job-name <name> [--dry-run]

说明:
  启用并加载指定任务。

选项:
  --job-name <name>   任务名称
  --dry-run           仅预览将执行的操作
  -h, --help          显示帮助
EOF
}

print_job_disable_help() {
  cat <<'EOF'
用法:
  macos-scripts job disable --job-name <name> [--dry-run]

说明:
  禁用并卸载指定任务。

选项:
  --job-name <name>   任务名称
  --dry-run           仅预览将执行的操作
  -h, --help          显示帮助
EOF
}

print_job_delete_help() {
  cat <<'EOF'
用法:
  macos-scripts job delete --job-name <name> [--dry-run]

说明:
  卸载并删除指定任务的 plist 文件。

选项:
  --job-name <name>   任务名称
  --dry-run           仅预览将执行的操作
  -h, --help          显示帮助
EOF
}

print_job_help() {
  cat <<'EOF'
用法:
  macos-scripts job <list|create|status|enable|disable|delete> [参数]

说明:
  该命令直接转发到 job/scheduler.sh。
EOF
}
