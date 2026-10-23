#!/bin/zsh
# filepath: src/main.sh
app_help() {
    printf '%s — %s\n用法: %s hello [--dry-run] | --help | --version\n' "$APP_COMMAND" "$APP_DESCRIPTION" "$APP_COMMAND"
}
app_main() {
    case "${1:---help}" in
        --help|-h) (( $# <= 1 )) || return 2; app_help; return 0 ;;
        --version) (( $# == 1 )) || return 2; printf '%s %s\n' "$APP_COMMAND" "$APP_VERSION"; return 0 ;;
        hello) shift ;;
        *) print -u2 -- "未知命令: $1；请运行 $APP_COMMAND --help"; return 2 ;;
    esac
    local dry_run=false
    if (( $# )); then
        [[ $# == 1 && "$1" == --dry-run ]] || { print -u2 '不支持的参数'; return 2; }
        dry_run=true
    fi
    source "$APP_ROOT/vendor/zsh-kit/lib/zsh-kit.sh" || return 1
    local version
    command -v sw_vers >/dev/null || { sk_error '需要 macOS'; return 1; }
    version="$(sw_vers -productVersion)" || return 1
    [[ "${version%%.*}" == <-> ]] && (( ${version%%.*} >= APP_MIN_MACOS )) || { sk_error "需要 macOS $APP_MIN_MACOS+"; return 1; }
    # Configuration policy belongs to this application; the library receives explicit paths.
    local log_key="${APP_ENV_PREFIX}_LOG_DIR" config_key="${APP_ENV_PREFIX}_CONFIG_DIR"
    local log_dir="${(P)log_key:-$APP_DEFAULT_LOG_DIR}" config_dir="${(P)config_key:-$APP_DEFAULT_CONFIG_DIR}"
    local SK_DRY_RUN="$dry_run"
    if [[ "$dry_run" == false ]]; then
        mkdir -p "$log_dir" || return 1
        sk_start_capture "$log_dir/run.log" || return 1
    fi
    sk_run_timed_command_or_fail hello '运行示例命令' '示例完成' '示例失败' '检查输出后重试' printf '%s\n' "Hello from $APP_COMMAND" || return $?
    return 0
}
