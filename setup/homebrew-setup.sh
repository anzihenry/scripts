#!/bin/zsh
# filepath: setup/homebrew-setup.sh

# ===== 初始化配置 =====
if [[ -n "${MACOS_SCRIPTS_LOG_DIR:-}" ]]; then
    mkdir -p "$MACOS_SCRIPTS_LOG_DIR"
    SETUP_LOG_FILE="$MACOS_SCRIPTS_LOG_DIR/homebrew-setup.log"
else
    SETUP_LOG_FILE="setup.log"
fi

exec > >(tee -a "$SETUP_LOG_FILE") 2>&1  # 启用日志记录
set -e                            # 错误立即退出
set -o pipefail                   # 管道错误捕获

# 引入颜色库
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/colors.sh"
source "$SCRIPT_DIR/lib/brew_helpers.sh"
source "$SCRIPT_DIR/lib/homebrew_config.sh"

BREW_BIN=""
DRY_RUN="false"

usage() {
        cat <<'EOF'
用法:
    homebrew-setup.sh [--dry-run]

说明:
    仅校准已安装 Homebrew 的镜像、shellenv 和当前环境。
    如果系统尚未安装 Homebrew，请改用 bootstrap/install.sh。

选项:
    --dry-run    仅预演将执行的配置动作，不修改 ~/.zshrc 或 Homebrew 仓库
    -h, --help   显示帮助
EOF
}

parse_args() {
        while [[ $# -gt 0 ]]; do
                case "$1" in
                        --dry-run)
                                DRY_RUN="true"
                                shift
                                ;;
                        -h|--help|help)
                                usage
                                exit 0
                                ;;
                        *)
                                error "未知参数: $1"
                                echo
                                usage
                                exit 1
                                ;;
                esac
        done
}

print_shell_refresh_notice() {
    print_header "环境刷新提示"
    warning "当前脚本运行在子 shell 中，无法直接刷新你已经打开的 terminal 会话。"
    info "配置完成后，请执行以下任一命令使 Homebrew 在当前 terminal 生效："
    print_code "source ~/.zshrc"
    print_code "exec zsh"
    info "如果当前 terminal 仍未生效，直接完全重启 terminal 即可。"
}

# ===== 预检模块 =====
precheck() {
    print_header "Homebrew 配置预检"

    if ! bh_require_commands curl git; then
        log_fatal "缺少必要命令，请确保 curl 与 git 已安装"
    fi

    # 系统版本检查 (macOS 10.15+)
    local os_version=$(sw_vers -productVersion)
    local major_version=$(echo $os_version | awk -F. '{print $1}')
    local minor_version=$(echo $os_version | awk -F. '{print $2}')
    local version_code=$(( major_version * 100 + minor_version ))
    
    if [[ $version_code -lt 1015 ]]; then
        log_fatal "需要 macOS Catalina (10.15) 或更高版本，当前版本：$os_version"
    fi

    # 网络连通性检查
    if ! curl -sIm3 --retry 2 --connect-timeout 30 https://mirrors.ustc.edu.cn >/dev/null; then
        if ! ping -c2 223.5.5.5 &>/dev/null; then
            log_fatal "中科大源异常，网络连接失败，请检查网络设置"
        fi
    fi

    if ! BREW_BIN="$(resolve_homebrew_bin)"; then
        log_fatal "未检测到 Homebrew。请先使用 bootstrap/install.sh 完成首次安装，再执行 setup brew configure。"
    fi

    "$BREW_BIN" --version >/dev/null 2>&1 || log_fatal "检测到 brew 可执行文件，但无法正常运行。"

    success "系统环境预检通过"
}

# ===== Homebrew 配置 =====
configure_homebrew() {
    print_header "配置 Homebrew"
    configure_homebrew_environment "$BREW_BIN" "$DRY_RUN"
    if [[ "$DRY_RUN" == "true" ]]; then
        success "Homebrew dry-run 预演完成 (版本: $($BREW_BIN --version | head -n1))"
    else
        success "Homebrew 配置完成 (版本: $($BREW_BIN --version | head -n1))"
    fi
}

# ===== 主执行流程 =====
main() {
    parse_args "$@"
    precheck
    configure_homebrew
    
    print_header "配置完成!"
    info "日志文件位置: $SETUP_LOG_FILE"
    info "如系统尚未安装 Homebrew，请改用 bootstrap/install.sh 完成首次安装。"
    [[ "$DRY_RUN" == "true" ]] && info "本次为 dry-run，未修改 ~/.zshrc 或 Homebrew 仓库配置。"
    print_shell_refresh_notice
}

# 启动主流程
main "$@"