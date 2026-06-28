#!/bin/zsh
# filepath: job/scheduler.sh

set -e
set -o pipefail
setopt EXTENDED_GLOB
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
JOB_LIB_DIR="${SCRIPT_DIR}/lib"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/colors.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/utils.sh"
# shellcheck disable=SC1091
source "${JOB_LIB_DIR}/job_paths.sh"
# shellcheck disable=SC1091
source "${JOB_LIB_DIR}/job_plist.sh"
# shellcheck disable=SC1091
source "${JOB_LIB_DIR}/job_launchctl.sh"
# shellcheck disable=SC1091
source "${JOB_LIB_DIR}/job_runtime.sh"
# shellcheck disable=SC1091
source "${JOB_LIB_DIR}/job_args.sh"
# shellcheck disable=SC1091
source "${JOB_LIB_DIR}/job_dispatch.sh"

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

build_job_plist_content() {
    local job_name="$1" script_path="$2" interval="$3" at_time="$4" weekday="$5"
    local keepalive_flag="$6" working_dir="$7" stdout_path="$8" stderr_path="$9" disabled_flag="${10}"
    shift 10
    local script_args=("$@")

    local label
    label="$(get_label "$job_name")"
    local program_block
    program_block="$(compose_program_arguments "$script_path" "${script_args[@]}")"
    local schedule_block
    schedule_block="$(compose_schedule_block "$interval" "$at_time" "$weekday")"
    compose_plist "$label" "$working_dir" "$stdout_path" "$stderr_path" "$keepalive_flag" "$disabled_flag" "$schedule_block" "$program_block"
}

ensure_job_plist_can_be_written() {
    local plist_path="$1"
    local dry_run="$2"

    if [[ -f "$plist_path" && "$NO_FORCE" == "1" ]]; then
        error "任务已存在，使用 --force 覆盖"
        exit 1
    fi

    if [[ -f "$plist_path" && "$NO_FORCE" == "0" && "$dry_run" != "1" ]]; then
        backup_existing_plist "$plist_path"
    fi
}

write_or_preview_job_plist() {
    local plist_path="$1"
    local plist_content="$2"
    local dry_run="$3"

    if [[ "$dry_run" == "1" ]]; then
        highlight "(dry-run) 将写入 plist 内容:"
        printf "%s\n" "$plist_content"
        return 0
    fi

    write_plist_file "$plist_path" "$plist_content"
    success "plist 写入完成"
}

resolve_job_load_behavior() {
    local disabled_flag="$1"
    local no_load_flag="$2"

    if [[ "$disabled_flag" == "1" ]]; then
        warning "已根据 --disabled 参数跳过加载"
        printf '1'
        return 0
    fi

    printf '%s' "$no_load_flag"
}

load_created_job_if_needed() {
    local plist_path="$1"
    local label="$2"
    local no_load_flag="$3"
    local dry_run="$4"

    if [[ "$no_load_flag" == "1" ]]; then
        warning "按 --no-load 参数跳过加载"
        return 0
    fi

    launchctl_bootstrap "$plist_path" "$label" "$dry_run"
}

resolve_job_execution_context() {
    local job_name="$1"
    JOB_ACTION_LABEL="$(get_label "$job_name")"
    JOB_ACTION_PLIST_PATH="$(get_plist_path "$job_name")"
}

ensure_job_plist_exists_for_action() {
    local plist_path="$1"
    if [[ ! -f "$plist_path" ]]; then
        error "任务文件不存在: ${plist_path}"
        exit 1
    fi
}

execute_create() {
    local job_name="$1" script_path="$2" interval="$3" at_time="$4" weekday="$5"
    local keepalive_flag="$6" working_dir="$7" stdout_path="$8" stderr_path="$9" disabled_flag="${10}" no_load_flag="${11}" dry_run="${12}"
    shift 12
    local script_args=("$@")

    job_timer_start "创建任务 ${job_name}" "创建任务 ${job_name}"

    ensure_job_directories
    resolve_job_execution_context "$job_name"

    local plist_content
    plist_content="$(build_job_plist_content "$job_name" "$script_path" "$interval" "$at_time" "$weekday" "$keepalive_flag" "$working_dir" "$stdout_path" "$stderr_path" "$disabled_flag" "${script_args[@]}")"

    info "目标 plist 文件: ${JOB_ACTION_PLIST_PATH}"

    ensure_job_plist_can_be_written "$JOB_ACTION_PLIST_PATH" "$dry_run"
    write_or_preview_job_plist "$JOB_ACTION_PLIST_PATH" "$plist_content" "$dry_run"

    local effective_no_load
    effective_no_load="$(resolve_job_load_behavior "$disabled_flag" "$no_load_flag")"
    load_created_job_if_needed "$JOB_ACTION_PLIST_PATH" "$JOB_ACTION_LABEL" "$effective_no_load" "$dry_run"

    job_timer_end "创建任务 ${job_name}" "创建任务 ${job_name}" "success"
}

execute_delete() {
    local job_name="$1" dry_run="$2"
    job_timer_start "删除任务 ${job_name}" "删除任务 ${job_name}"
    resolve_job_execution_context "$job_name"
    if [[ ! -f "$JOB_ACTION_PLIST_PATH" ]]; then
        warning "未找到任务文件: ${JOB_ACTION_PLIST_PATH}"
        job_timer_end "删除任务 ${job_name}" "删除任务 ${job_name}" "warning"
        return
    fi

    launchctl_bootout "$JOB_ACTION_LABEL" "$dry_run"

    if [[ "$dry_run" == "1" ]]; then
        info "(dry-run) 将移除: ${JOB_ACTION_PLIST_PATH}"
    else
        rm -f "$JOB_ACTION_PLIST_PATH"
        success "已删除 plist"
    fi
    job_timer_end "删除任务 ${job_name}" "删除任务 ${job_name}" "success"
}

execute_enable() {
    local job_name="$1" dry_run="$2"
    resolve_job_execution_context "$job_name"
    ensure_job_plist_exists_for_action "$JOB_ACTION_PLIST_PATH"
    launchctl_bootstrap "$JOB_ACTION_PLIST_PATH" "$JOB_ACTION_LABEL" "$dry_run"
    if [[ "$dry_run" != "1" ]]; then
        success "任务已启用"
    fi
}

execute_disable() {
    local job_name="$1" dry_run="$2"
    resolve_job_execution_context "$job_name"
    launchctl_disable "$JOB_ACTION_LABEL" "$dry_run"
    launchctl_bootout "$JOB_ACTION_LABEL" "$dry_run"
    if [[ "$dry_run" != "1" ]]; then
        success "任务已禁用"
    fi
}

main() {
    initialize_scheduler_context "$@"
    run_scheduler_entry
}

if [[ "${JOB_SCHEDULER_SOURCE_ONLY:-0}" != "1" ]]; then
    main "$@"
fi
