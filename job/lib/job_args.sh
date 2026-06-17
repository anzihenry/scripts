#!/bin/zsh

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

parse_scheduler_args() {
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
