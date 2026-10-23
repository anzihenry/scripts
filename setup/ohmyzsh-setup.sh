#!/bin/zsh
# filepath: setup/ohmyzsh-setup.sh
set -euo pipefail
SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/../lib/colors.sh"
source "$SCRIPT_DIR/../lib/utils.sh"
source "$SCRIPT_DIR/lib/config_writer.sh"
source "$SCRIPT_DIR/lib/shell_setup.sh"

source "$SCRIPT_DIR/lib/setup_options.sh"
source "$SCRIPT_DIR/../lib/workflow.sh"
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

main() {
    parse_shell_options "$@" || return $?
    if [[ "$SETUP_HELP" == true ]]; then
        printf '用法: ohmyzsh-setup.sh [--dry-run]\n说明: 幂等配置 Oh My Zsh、主题、插件和字体；保留用户配置。\n'
        return 0
    fi
    if [[ "$SETUP_DRY_RUN" == true ]]; then
        info "[dry-run] 将检查 Command Line Tools，安装缺失的 Oh My Zsh、Powerlevel10k、zsh-syntax-highlighting、zsh-autosuggestions。"
        info "[dry-run] 将更新 ~/.zshrc 管理块，安装或修复 ~/Library/Fonts/MesloLGS NF 的四款字体；保留已有健康仓库和自定义配置。"
        return 0
    fi
    require_supported_macos || exit 1
    require_commands git curl od
    SETUP_LOG_FILE="$(prepare_log_file_path setup-shell.log)" || return 1
    enable_log_capture "$SETUP_LOG_FILE" || return 1
    local state_dir="${MACOS_SCRIPTS_CONFIG_DIR:-$HOME/.config/macos-scripts}"
    mkdir -p "$state_dir" || exit 1
    SHELL_SETUP_LOCK="$state_dir/.setup-shell.lock"
    [[ ! -e "$SHELL_SETUP_LOCK" ]] || { error "存在旧版终端配置锁，请确认旧进程已结束后清理: $SHELL_SETUP_LOCK"; return 1; }
    resource_lock_acquire "setup-shell:${HOME:A}" || return 1
    run_stages 开发工具 ensure_xcode_cli_installed 框架 install_oh_my_zsh 主题 install_p10k_theme \
        插件 install_plugins Shell配置 update_zsh_config 字体 install_fonts || return $?
    success "终端配置已就绪；已有主题和插件设置保留。可执行 exec zsh 刷新。"
    info "日志文件位置: $SETUP_LOG_FILE"
}
main "$@" || exit $?
