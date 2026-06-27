#!/bin/zsh

initialize_scheduler_context() {
    typeset -gA JOB_TIMERS
    ACTION="${1:-}"
    SCHEDULER_ARGS=("${@:2}")
}

_job_timer_key() {
    local raw="${1:-default}"
    echo "${raw//[^A-Za-z0-9]/_}" | tr '[:lower:]' '[:upper:]'
}

job_timer_start() {
    local key="$(_job_timer_key "$1")"
    local message="${2:-}"
    local now
    now="$(date +%s 2>/dev/null || printf '%s' "${EPOCHSECONDS:-0}")"
    JOB_TIMERS[$key]="$now"
    [[ -n "$message" ]] && info "$message (开始)"
}

job_timer_end() {
    local key="$(_job_timer_key "$1")"
    local message="${2:-任务完成}"
    local level="${3:-success}"
    local start="${JOB_TIMERS[$key]-}"

    if [[ -z "$start" ]]; then
        warning "未找到计时器：$1"
        return 1
    fi

    local now
    now="$(date +%s 2>/dev/null || printf '%s' "${EPOCHSECONDS:-0}")"
    local duration=$(( now - start ))
    local formatted
    formatted="$(__color_format_duration "$duration")"

    case "$level" in
        success|ok)
            success "${message}，耗时 ${formatted}"
            ;;
        warn|warning)
            warning "${message}，耗时 ${formatted}"
            ;;
        *)
            error "${message}，耗时 ${formatted}"
            ;;
    esac

    unset "JOB_TIMERS[$key]"
}

run_scheduler_entry() {
    if [[ -z "$ACTION" || "$ACTION" == "--help" || "$ACTION" == "-h" ]]; then
        print_usage
        exit 0
    fi

    require_command launchctl
    require_command plutil

    init_scheduler_args
    parse_scheduler_args "${SCHEDULER_ARGS[@]}"
    dispatch_scheduler_action
}
