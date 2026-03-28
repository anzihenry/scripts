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

get_default_brew_prefix() {
    if [[ "$(uname -m)" == "arm64" ]]; then
        printf '%s' "/opt/homebrew"
    else
        printf '%s' "/usr/local"
    fi
}

resolve_brew_bin() {
    if command -v brew &>/dev/null; then
        command -v brew
        return 0
    fi

    if [[ -x /opt/homebrew/bin/brew ]]; then
        printf '%s' "/opt/homebrew/bin/brew"
        return 0
    fi

    if [[ -x /usr/local/bin/brew ]]; then
        printf '%s' "/usr/local/bin/brew"
        return 0
    fi

    return 1
}

activate_brew_for_script() {
    local brew_bin="$1"
    local brew_prefix
    brew_prefix="$("$brew_bin" --prefix)"

    export PATH="${brew_prefix}/bin:${brew_prefix}/sbin:$PATH"
    eval "$("$brew_bin" shellenv)"
}

update_homebrew_shell_config() {
    local brew_prefix="$1"
    local rc_file="$HOME/.zshrc"
    local start_marker="# >>> Homebrew Basic (managed by homebrew-setup) >>>"
    local end_marker="# <<< Homebrew Basic (managed by homebrew-setup) <<<"

    touch "$rc_file"

    if grep -Fq "$start_marker" "$rc_file"; then
        sed -i '' "\\|$start_marker|,\\|$end_marker|d" "$rc_file"
    fi

    {
        echo ""
        echo "$start_marker"
        echo "export PATH=\"${brew_prefix}/bin:${brew_prefix}/sbin:\$PATH\""
        echo "eval \"\$(${brew_prefix}/bin/brew shellenv)\""
        echo "$end_marker"
    } >> "$rc_file"

    success "已更新 ~/.zshrc 中的 Homebrew 配置"
}

print_shell_refresh_notice() {
    print_header "环境刷新提示"
    warning "当前脚本运行在子 shell 中，无法直接刷新你已经打开的 terminal 会话。"
    info "安装完成后，请执行以下任一命令使 Homebrew 在当前 terminal 生效："
    print_code "source ~/.zshrc"
    print_code "exec zsh"
    info "如果当前 terminal 仍未生效，直接完全重启 terminal 即可。"
}

# ===== 预检模块 =====
precheck() {
    print_header "系统环境预检"

    if ! bh_require_commands curl; then
        log_fatal "缺少必要命令，请确保 curl 已安装"
    fi

    # 系统版本检查 (macOS 10.15+)
    local os_version=$(sw_vers -productVersion)
    local major_version=$(echo $os_version | awk -F. '{print $1}')
    local minor_version=$(echo $os_version | awk -F. '{print $2}')
    local version_code=$(( major_version * 100 + minor_version ))
    
    if [[ $version_code -lt 1015 ]]; then
        log_fatal "需要 macOS Catalina (10.15) 或更高版本，当前版本：$os_version"
    fi

    # 磁盘空间检查 (15GB+)
    local free_space=$(df -g / | tail -1 | awk '{print $4}')
    [[ $free_space -lt 15 ]] && log_fatal "磁盘空间不足15GB (剩余: ${free_space}GB)"

    # 网络连通性检查
    if ! curl -sIm3 --retry 2 --connect-timeout 30 https://mirrors.ustc.edu.cn >/dev/null; then
        if ! ping -c2 223.5.5.5 &>/dev/null; then
            log_fatal "中科大源异常，网络连接失败，请检查网络设置"
        fi
    fi

    success "系统环境预检通过"
}

# ===== Xcode CLI 工具安装 =====
install_xcode_cli() {
    print_header "安装 Xcode 命令行工具"
    
    if ! xcode-select -p &>/dev/null; then
        warning "正在安装 Xcode CLI 工具... 请在弹出的窗口中完成安装。"
        xcode-select --install
        
        # 使用固定的轮询间隔等待安装完成
        local wait_count=0
        local max_wait=60 # 最多等待 60 * 5 = 300 秒
        until xcode-select -p &>/dev/null; do
            info "等待 Xcode CLI 安装完成... (${wait_count}/${max_wait})"
            sleep 5
            ((wait_count++))
            [[ $wait_count -gt $max_wait ]] && log_fatal "安装超时，请手动执行: xcode-select --install"
        done
        
        # 验证编译器存在
        [[ -f /usr/bin/clang ]] || log_fatal "CLI 工具安装不完整"
    fi
    success "Xcode 命令行工具就绪"
}

# ===== Homebrew 安装 =====
install_homebrew() {
    print_header "安装 Homebrew"

    local brew_prefix
    local brew_bin=""
    brew_prefix="$(get_default_brew_prefix)"

    if ! brew_bin="$(resolve_brew_bin)"; then
        warning "正在尝试官方源安装..."

        # 临时取消错误中断以处理安装失败
        set +e
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        local install_status=$?
        set -e

        if [ $install_status -eq 0 ]; then
            success "官方源安装成功"
        else
            warning "官方源安装失败 (状态码 $install_status)，尝试中科大镜像..."
            /bin/bash -c "$(curl -fsSL https://mirrors.ustc.edu.cn/misc/brew-install.sh)" || {
                log_fatal "Homebrew 安装失败，请检查网络连接"
            }
        fi

        brew_bin="${brew_prefix}/bin/brew"
        [[ -x "$brew_bin" ]] || log_fatal "Homebrew 安装后未找到 brew 可执行文件: $brew_bin"

        activate_brew_for_script "$brew_bin"
        update_homebrew_shell_config "$brew_prefix"
    else
        brew_prefix="$("$brew_bin" --prefix)"
        activate_brew_for_script "$brew_bin"
        update_homebrew_shell_config "$brew_prefix"
        info "检测到已安装 Homebrew，已校准当前脚本环境与 ~/.zshrc 配置"
    fi

    # 验证安装
    if ! brew_bin="$(resolve_brew_bin)" || ! "$brew_bin" --version &>/dev/null; then
        log_fatal "Homebrew 安装验证失败，请检查 ~/.zshrc 配置或重新运行脚本。"
    fi

    success "Homebrew 安装完成 (版本: $($brew_bin --version | head -n1))"
}

# ===== 主执行流程 =====
main() {
    precheck
    install_xcode_cli
    install_homebrew
    
    print_header "安装完成!"
    info "日志文件位置: $SETUP_LOG_FILE"
    print_shell_refresh_notice
}

# 启动主流程
main