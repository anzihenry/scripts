#!/bin/zsh
# filepath: setup/ohmyzsh-setup.sh
set -euo pipefail
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/../lib/colors.sh"
source "$SCRIPT_DIR/../lib/utils.sh"
source "$SCRIPT_DIR/lib/config_writer.sh"
source "$SCRIPT_DIR/lib/shell_setup.sh"

SHELL_SETUP_LOCK_HELD=false
cleanup_shell_setup_lock() {
    if [[ "$SHELL_SETUP_LOCK_HELD" == true ]]; then
        rmdir "$SHELL_SETUP_LOCK" || warning "终端配置锁清理失败，请检查: $SHELL_SETUP_LOCK"
        SHELL_SETUP_LOCK_HELD=false
    fi
}
trap cleanup_shell_setup_lock EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

main() {
    case "${1:-}" in
        -h|--help|help) printf '用法: ohmyzsh-setup.sh\n说明: 幂等配置 Oh My Zsh、主题、插件和字体；保留用户配置。\n'; return 0 ;;
        '') ;;
        *) error "未知参数: $1"; return 1 ;;
    esac
    require_supported_macos || exit 1
    require_commands git curl od
    SETUP_LOG_FILE="$(prepare_log_file_path setup-shell.log)"
    enable_log_capture "$SETUP_LOG_FILE"
    local state_dir="${MACOS_SCRIPTS_CONFIG_DIR:-$HOME/.config/macos-scripts}"
    mkdir -p "$state_dir" || exit 1
    SHELL_SETUP_LOCK="$state_dir/.setup-shell.lock"
    if ! (umask 077; mkdir "$SHELL_SETUP_LOCK") 2>/dev/null; then
        error "另一个终端配置可能正在运行；确认结束后再清理锁: $SHELL_SETUP_LOCK"
        exit 1
    fi
    SHELL_SETUP_LOCK_HELD=true
    ensure_xcode_cli_installed || exit $?
    install_oh_my_zsh || exit $?
    install_p10k_theme || exit $?
    install_plugins || exit $?
    update_zsh_config || exit $?
    install_fonts || exit $?
    success "终端配置已就绪；已有主题和插件设置保留。可执行 exec zsh 刷新。"
    info "日志文件位置: $SETUP_LOG_FILE"
}
main "$@"
