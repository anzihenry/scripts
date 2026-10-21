#!/bin/zsh
# filepath: maintain/lib/brew_updater_args.sh

initialize_brew_updater_context() {
    typeset -ga EXCLUDED_CASKS=(
        "microsoft-.*"
        "android-studio"
        "visual-studio-code"
        "docker-desktop"
        "iterm2"
        "google-chrome"
        "feishu"
        "lark"
        "chatgpt"
    )

    DRY_RUN="false"
    ASSUME_YES="false"
    FORCE_CASKS="false"
    SKIP_FORMULAE="false"
    SKIP_CASKS="false"
    SKIP_CLEANUP="false"

    typeset -ga UPDATED_CASKS=()
    typeset -ga SKIPPED_CASKS=()
    typeset -ga FAILED_CASKS=()
}

parse_brew_updater_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN="true"
                ;;
            --yes|-y)
                ASSUME_YES="true"
                ;;
            --force)
                FORCE_CASKS="true"
                ;;
            --skip-formulae)
                SKIP_FORMULAE="true"
                ;;
            --skip-casks)
                SKIP_CASKS="true"
                ;;
            --skip-cleanup)
                SKIP_CLEANUP="true"
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_fatal "未知参数: $1"
                ;;
        esac
        shift
    done
}

initialize_brew_updater_logging() {
    ERROR_LOG="$(prepare_log_file_path "brew_update_errors.log")" || return 1
    BREW_UPDATE_LOG_STARTED=false
    BREW_UPDATE_RUN_STARTED_AT="$(date '+%Y-%m-%d %H:%M:%S %z')"
}
