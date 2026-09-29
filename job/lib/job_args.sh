#!/bin/zsh

# 校验「带值选项」后面确实还有值（$remaining 为当前剩余参数个数）。
# 使用 `if !` 而非 `... || return 1`：在 zsh 下 `f || return` 会输出
# "can only return from a function or sourced script" 警告。
_require_option_value() {
    local option="$1"
    local remaining="$2"

    if [[ $remaining -lt 2 ]]; then
        error "$option 需要一个参数值"
        print_usage
        return 1
    fi
    return 0
}

init_scheduler_args() {
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
}

# 读取选项值前校验剩余参数个数。
# 脚本运行在 set -u 下：末位 `--interval`（无值）若直接读 "$2" 会抛
# "2: parameter not set" 并暴露内部行号，而不是给出可读的用法错误。
parse_scheduler_args() {
    local remaining=$#

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --job-name)
                _require_option_value "$1" "$remaining" || return 1
                JOB_NAME="$2"
                shift 2
                remaining=$((remaining - 2))
                ;;
            --script)
                _require_option_value "$1" "$remaining" || return 1
                TARGET_SCRIPT="$2"
                shift 2
                remaining=$((remaining - 2))
                ;;
            --interval)
                _require_option_value "$1" "$remaining" || return 1
                INTERVAL="$2"
                shift 2
                remaining=$((remaining - 2))
                ;;
            --at)
                _require_option_value "$1" "$remaining" || return 1
                AT_TIME="$2"
                shift 2
                remaining=$((remaining - 2))
                ;;
            --weekday)
                _require_option_value "$1" "$remaining" || return 1
                WEEKDAY="$2"
                shift 2
                remaining=$((remaining - 2))
                ;;
            --keepalive)
                KEEPALIVE=1
                shift
                remaining=$((remaining - 1))
                ;;
            --working-dir)
                _require_option_value "$1" "$remaining" || return 1
                WORKING_DIR="$2"
                shift 2
                remaining=$((remaining - 2))
                ;;
            --stdout)
                _require_option_value "$1" "$remaining" || return 1
                STDOUT_PATH="$2"
                shift 2
                remaining=$((remaining - 2))
                ;;
            --stderr)
                _require_option_value "$1" "$remaining" || return 1
                STDERR_PATH="$2"
                shift 2
                remaining=$((remaining - 2))
                ;;
            --no-load)
                NO_LOAD=1
                shift
                remaining=$((remaining - 1))
                ;;
            --disabled)
                DISABLED=1
                shift
                remaining=$((remaining - 1))
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                remaining=$((remaining - 1))
                ;;
            --force)
                NO_FORCE=0
                shift
                remaining=$((remaining - 1))
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

    return 0
}

prepare_create_args() {
    validate_job_name "$JOB_NAME"

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
}
