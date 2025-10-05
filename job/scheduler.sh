#!/bin/zsh
# filepath: /Users/xiejinheng/Coding/scripts/job/scheduler.sh

set -e
set -u
set -o pipefail
setopt EXTENDED_GLOB

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/../lib/colors.sh"

JOB_LABEL_PREFIX="com.coding.scripts.job"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
LOG_BASE_DIR="${HOME}/Library/Logs/scripts-jobs"

print_usage() {
    cat <<'EOF'
用法: scheduler.sh <action> [参数] [-- 脚本参数...]

动作列表:
  create   创建或更新任务并默认加载
  delete   卸载并删除任务
  enable   启用并加载任务
  disable  禁用并卸载任务
  status   查看任务状态
  list     列出所有脚本前缀任务

常用参数:
  --job-name <名称>            任务标识（必填）
  --script <路径>              目标脚本（create 时必填）
  --interval <分钟>            以分钟为单位的循环间隔
  --at <HH:MM>                指定每日运行时间（24 小时制）
  --weekday <0-6>             限定每周某天执行（0=周日）
  --keepalive                 当进程异常退出时自动重启
  --working-dir <路径>        设置 WorkingDirectory，默认仓库根目录
  --stdout <文件>             标准输出日志文件
  --stderr <文件>             标准错误日志文件
  --no-load                   创建后不立即加载任务
  --disabled                  创建时在 plist 中标记 Disabled
  --force                     允许覆盖同名任务并备份旧文件
  --dry-run                   仅显示计划动作，不执行
  --help                      展示此帮助

注意: 在 `--` 之后的参数会原样传递给目标脚本。
EOF
}

require_command() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        error "缺少依赖: ${cmd}，请手动安装或检查 PATH"
        exit 1
    fi
}

xml_escape() {
    local input="$1"
    local escaped="${input//&/&amp;}"
    escaped="${escaped//</&lt;}"
    escaped="${escaped//>/&gt;}"
    escaped="${escaped//\"/&quot;}"
    escaped="${escaped//'/&apos;}"
    printf "%s" "$escaped"
}

resolve_path() {
    local path="$1"
    if [[ "$path" == /* ]]; then
        printf "%s" "$path"
        return
    fi
    local dir_part="$(dirname "$path")"
    local base_part="$(basename "$path")"
    local resolved_dir
    if ! resolved_dir="$(cd "$PWD" && cd "$dir_part" 2>/dev/null && pwd)"; then
        error "无法解析路径: $path"
        exit 1
    fi
    printf "%s/%s" "$resolved_dir" "$base_part"
}

resolve_directory() {
    local path="$1"
    local resolved="$(resolve_path "$path")"
    if [[ ! -d "$resolved" ]]; then
        error "目录不存在: $resolved"
        exit 1
    fi
    printf "%s" "$resolved"
}

get_plist_path() {
    local job_name="$1"
    printf "%s/%s.%s.plist" "$LAUNCH_AGENTS_DIR" "$JOB_LABEL_PREFIX" "$job_name"
}

get_label() {
    local job_name="$1"
    printf "%s.%s" "$JOB_LABEL_PREFIX" "$job_name"
}

validate_job_name() {
    local job_name="$1"
    if [[ -z "$job_name" ]]; then
        error "任务名称不能为空"
        exit 1
    fi
    if ! [[ "$job_name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        error "任务名称仅支持字母、数字、点、下划线与短横"
        exit 1
    fi
}

validate_script() {
    local script_path="$1"
    if [[ ! -f "$script_path" ]]; then
        error "目标脚本不存在: $script_path"
        exit 1
    fi
    if [[ ! -x "$script_path" ]]; then
        error "目标脚本不可执行，请先运行: chmod +x \"$script_path\""
        exit 1
    fi
}

ensure_directories() {
    mkdir -p "$LAUNCH_AGENTS_DIR"
    mkdir -p "$LOG_BASE_DIR"
}

compose_program_arguments() {
    local script_path="$1"
    shift
    local args=("$script_path" "$@")
    local xml="    <key>ProgramArguments</key>\n    <array>\n"
    local arg
    for arg in "${args[@]}"; do
        xml+="      <string>$(xml_escape "$arg")</string>\n"
    done
    xml+="    </array>\n"
    printf "%s" "$xml"
}

compose_schedule_block() {
    local interval_minutes="$1"
    local at_time="$2"
    local weekday="$3"
    local xml=""
    if [[ -n "$interval_minutes" ]]; then
        local seconds=$((interval_minutes * 60))
        if (( seconds <= 0 )); then
            error "--interval 必须为正整数"
            exit 1
        fi
        xml+="    <key>StartInterval</key>\n    <integer>${seconds}</integer>\n"
    fi
    if [[ -n "$at_time" ]]; then
        if [[ ! "$at_time" =~ ^[0-2][0-9]:[0-5][0-9]$ ]]; then
            error "--at 格式必须为 HH:MM"
            exit 1
        fi
        local hour="${at_time%%:*}"
        local minute="${at_time##*:}"
        xml+="    <key>StartCalendarInterval</key>\n    <dict>\n      <key>Hour</key>\n      <integer>${hour#0}</integer>\n      <key>Minute</key>\n      <integer>${minute#0}</integer>\n"
        if [[ -n "$weekday" ]]; then
            if ! [[ "$weekday" =~ ^[0-6]$ ]]; then
                error "--weekday 取值范围 0-6"
                exit 1
            fi
            xml+="      <key>Weekday</key>\n      <integer>${weekday}</integer>\n"
        fi
        xml+="    </dict>\n"
    fi
    if [[ -z "$xml" ]]; then
        error "需要指定 --interval 或 --at"
        exit 1
    fi
    printf "%s" "$xml"
}

compose_plist() {
    local label="$1"
    local working_dir="$2"
    local stdout_path="$3"
    local stderr_path="$4"
    local keepalive="$5"
    local disabled="$6"
    local schedule_block="$7"
    local program_block="$8"

    local xml_header="<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<dict>\n    <key>Label</key>\n    <string>${label}</string>\n"

    local xml_footer="</dict>\n</plist>\n"

    local xml_body="${program_block}    <key>WorkingDirectory</key>\n    <string>$(xml_escape "$working_dir")</string>\n    <key>StandardOutPath</key>\n    <string>$(xml_escape "$stdout_path")</string>\n    <key>StandardErrorPath</key>\n    <string>$(xml_escape "$stderr_path")</string>\n    <key>RunAtLoad</key>\n    <true/>\n"

    if [[ "$keepalive" == "1" ]]; then
        xml_body+="    <key>KeepAlive</key>\n    <true/>\n"
    fi

    xml_body+="$schedule_block"

    if [[ "$disabled" == "1" ]]; then
        xml_body+="    <key>Disabled</key>\n    <true/>\n"
    fi

    printf "%s%s%s" "$xml_header" "$xml_body" "$xml_footer"
}

backup_existing_plist() {
    local plist_path="$1"
    local backup_dir="${plist_path}.bak"
    local timestamp="$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    local backup_path="${backup_dir}/$(basename "$plist_path").${timestamp}"
    cp "$plist_path" "$backup_path"
    info "已备份旧版本: ${backup_path}"
}

write_plist_file() {
    local plist_path="$1"
    local plist_content="$2"
    printf "%s" "$plist_content" > "$plist_path"
    plutil -lint "$plist_path" >/dev/null
}

launchctl_bootstrap() {
    local plist_path="$1"
    local label="$2"
    local dry_run="$3"
    local current_session="gui/$(id -u)"

    if [[ "$dry_run" == "1" ]]; then
        info "(dry-run) 将执行: launchctl bootout ${current_session}/${label} (忽略不存在的错误)"
        info "(dry-run) 将执行: launchctl bootstrap ${current_session} ${plist_path}"
        info "(dry-run) 将执行: launchctl enable ${current_session}/${label}"
        return
    fi

    if launchctl print "${current_session}/${label}" >/dev/null 2>&1; then
        info "卸载已存在的任务 ${label}"
        launchctl bootout "${current_session}/${label}" >/dev/null 2>&1 || true
    fi
    info "加载新任务 ${label}"
    launchctl bootstrap "${current_session}" "$plist_path"
    info "启用任务 ${label}"
    launchctl enable "${current_session}/${label}"
}

launchctl_bootout() {
    local label="$1"
    local dry_run="$2"
    local current_session="gui/$(id -u)"
    if [[ "$dry_run" == "1" ]]; then
        info "(dry-run) 将执行: launchctl bootout ${current_session}/${label}"
        return
    fi
    if launchctl print "${current_session}/${label}" >/dev/null 2>&1; then
        info "卸载任务 ${label}"
        launchctl bootout "${current_session}/${label}"
    else
        warning "未检测到正在运行的任务"
    fi
}

launchctl_disable() {
    local label="$1"
    local dry_run="$2"
    local current_session="gui/$(id -u)"
    if [[ "$dry_run" == "1" ]]; then
        info "(dry-run) 将执行: launchctl disable ${current_session}/${label}"
        return
    fi
    launchctl disable "${current_session}/${label}" || warning "禁用命令返回非零"
}

show_status() {
    local job_name="$1"
    local label
    label="$(get_label "$job_name")"
    local current_session="gui/$(id -u)"
    info "查看任务 ${label} 状态..."
    if launchctl print "${current_session}/${label}" >/dev/null 2>&1; then
        launchctl print "${current_session}/${label}" | sed 's/^/    /'
        success "任务处于已加载状态"
    else
        warning "任务未加载，可使用 enable 或 create --no-load false 重新加载"
    fi
}

list_jobs() {
    info "列出当前用户的脚本任务..."
    local count=0
    for plist in "$LAUNCH_AGENTS_DIR"/${JOB_LABEL_PREFIX}.*.plist(N); do
        [[ -f "$plist" ]] || continue
        local job_name
        job_name="${plist##*.job.}"
        job_name="${job_name%.plist}"
        printf "  - %s (%s)\n" "$job_name" "$plist"
        ((count++))
    done
    if (( count == 0 )); then
        warning "未找到任何 ${JOB_LABEL_PREFIX} 前缀的任务"
    fi
}

sanitize_log_path() {
    local path="$1"
    if [[ -z "$path" ]]; then
        printf "%s" "$path"
        return
    fi
    local dir="$(dirname "$path")"
    mkdir -p "$dir"
    printf "%s" "$path"
}

execute_create() {
    local job_name="$1" script_path="$2" interval="$3" at_time="$4" weekday="$5"
    local keepalive_flag="$6" working_dir="$7" stdout_path="$8" stderr_path="$9" disabled_flag="${10}" no_load_flag="${11}" dry_run="${12}"
    shift 12
    local script_args=("$@")

    log_time_start "创建任务 ${job_name}"

    ensure_directories

    local label
    label="$(get_label "$job_name")"
    local plist_path
    plist_path="$(get_plist_path "$job_name")"

    local program_block
    program_block="$(compose_program_arguments "$script_path" "${script_args[@]}")"
    local schedule_block
    schedule_block="$(compose_schedule_block "$interval" "$at_time" "$weekday")"
    local plist_content
    plist_content="$(compose_plist "$label" "$working_dir" "$stdout_path" "$stderr_path" "$keepalive_flag" "$disabled_flag" "$schedule_block" "$program_block")"

    info "目标 plist 文件: ${plist_path}"

    if [[ -f "$plist_path" && "$NO_FORCE" == "1" ]]; then
        error "任务已存在，使用 --force 覆盖"
        exit 1
    fi

    if [[ -f "$plist_path" && "$NO_FORCE" == "0" && "$dry_run" != "1" ]]; then
        backup_existing_plist "$plist_path"
    fi

    if [[ "$dry_run" == "1" ]]; then
        highlight "(dry-run) 将写入 plist 内容:"
        printf "%s\n" "$plist_content"
    else
        write_plist_file "$plist_path" "$plist_content"
        success "plist 写入完成"
    fi

    if [[ "$disabled_flag" == "1" ]]; then
        no_load_flag="1"
        warning "已根据 --disabled 参数跳过加载"
    fi

    if [[ "$no_load_flag" == "1" ]]; then
        warning "按 --no-load 参数跳过加载"
    else
        launchctl_bootstrap "$plist_path" "$label" "$dry_run"
    fi

    log_time_end "创建任务 ${job_name}"
}

execute_delete() {
    local job_name="$1" dry_run="$2"
    log_time_start "删除任务 ${job_name}"
    local label
    label="$(get_label "$job_name")"
    local plist_path
    plist_path="$(get_plist_path "$job_name")"
    if [[ ! -f "$plist_path" ]]; then
        warning "未找到任务文件: ${plist_path}"
        log_time_end "删除任务 ${job_name}"
        return
    fi

    launchctl_bootout "$label" "$dry_run"

    if [[ "$dry_run" == "1" ]]; then
        info "(dry-run) 将移除: ${plist_path}"
    else
        rm -f "$plist_path"
        success "已删除 plist"
    fi
    log_time_end "删除任务 ${job_name}"
}

execute_enable() {
    local job_name="$1" dry_run="$2"
    local label
    label="$(get_label "$job_name")"
    local plist_path
    plist_path="$(get_plist_path "$job_name")"
    if [[ ! -f "$plist_path" ]]; then
        error "任务文件不存在: ${plist_path}"
        exit 1
    fi
    launchctl_bootstrap "$plist_path" "$label" "$dry_run"
    if [[ "$dry_run" != "1" ]]; then
        success "任务已启用"
    fi
}

execute_disable() {
    local job_name="$1" dry_run="$2"
    local label
    label="$(get_label "$job_name")"
    launchctl_disable "$label" "$dry_run"
    launchctl_bootout "$label" "$dry_run"
    if [[ "$dry_run" != "1" ]]; then
        success "任务已禁用"
    fi
}

ACTION="${1:-}" || true
if [[ -z "$ACTION" || "$ACTION" == "--help" || "$ACTION" == "-h" ]]; then
    print_usage
    exit 0
fi
shift || true

require_command launchctl
require_command plutil

JOB_NAME=""
TARGET_SCRIPT=""
INTERVAL=""
AT_TIME=""
WEEKDAY=""
KEEPALIVE=0
WORKING_DIR="$REPO_ROOT"
STDOUT_PATH=""
STDERR_PATH=""
DRY_RUN=0
NO_LOAD=0
DISABLED=0
NO_FORCE=1
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --job-name)
            JOB_NAME="$2"
            shift 2
            ;;
        --script)
            TARGET_SCRIPT="$2"
            shift 2
            ;;
        --interval)
            INTERVAL="$2"
            shift 2
            ;;
        --at)
            AT_TIME="$2"
            shift 2
            ;;
        --weekday)
            WEEKDAY="$2"
            shift 2
            ;;
        --keepalive)
            KEEPALIVE=1
            shift
            ;;
        --working-dir)
            WORKING_DIR="$2"
            shift 2
            ;;
        --stdout)
            STDOUT_PATH="$2"
            shift 2
            ;;
        --stderr)
            STDERR_PATH="$2"
            shift 2
            ;;
        --no-load)
            NO_LOAD=1
            shift
            ;;
        --disabled)
            DISABLED=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --force)
            NO_FORCE=0
            shift
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        --)
            shift
            EXTRA_ARGS=("$@")
            break
            ;;
        *)
            error "未识别的参数: $1"
            print_usage
            exit 1
            ;;
    esac
done

validate_job_name "$JOB_NAME"

if [[ "$ACTION" == "create" ]]; then
    if [[ -z "$TARGET_SCRIPT" ]]; then
        error "create 动作需要提供 --script"
        exit 1
    fi
    if [[ -n "$INTERVAL" && ! "$INTERVAL" =~ ^[0-9]+$ ]]; then
        error "--interval 需要正整数"
        exit 1
    fi
    TARGET_SCRIPT="$(resolve_path "$TARGET_SCRIPT")"
    validate_script "$TARGET_SCRIPT"

    WORKING_DIR="$(resolve_directory "$WORKING_DIR")"

    if [[ -z "$STDOUT_PATH" ]]; then
        STDOUT_PATH="${LOG_BASE_DIR}/${JOB_NAME}.out.log"
    else
        STDOUT_PATH="$(sanitize_log_path "$STDOUT_PATH")"
    fi
    if [[ -z "$STDERR_PATH" ]]; then
        STDERR_PATH="${LOG_BASE_DIR}/${JOB_NAME}.err.log"
    else
        STDERR_PATH="$(sanitize_log_path "$STDERR_PATH")"
    fi

    execute_create "$JOB_NAME" "$TARGET_SCRIPT" "$INTERVAL" "$AT_TIME" "$WEEKDAY" "$KEEPALIVE" "$WORKING_DIR" "$STDOUT_PATH" "$STDERR_PATH" "$DISABLED" "$NO_LOAD" "$DRY_RUN" "${EXTRA_ARGS[@]}"
    exit 0
fi

if [[ "$ACTION" == "delete" ]]; then
    execute_delete "$JOB_NAME" "$DRY_RUN"
    exit 0
fi

if [[ "$ACTION" == "enable" ]]; then
    execute_enable "$JOB_NAME" "$DRY_RUN"
    exit 0
fi

if [[ "$ACTION" == "disable" ]]; then
    execute_disable "$JOB_NAME" "$DRY_RUN"
    exit 0
fi

if [[ "$ACTION" == "status" ]]; then
    show_status "$JOB_NAME"
    exit 0
fi

if [[ "$ACTION" == "list" ]]; then
    list_jobs
    exit 0
fi

error "未知动作: ${ACTION}"
print_usage
exit 1
