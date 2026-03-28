#!/bin/zsh
# filepath: setup/macos-setup.sh

# ===== 初始化配置 =====
exec > >(tee -a setup.log) 2>&1  # 启用日志记录
set -e                            # 错误立即退出
set -o pipefail                   # 管道错误捕获

# 引入颜色库
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/colors.sh"
source "$SCRIPT_DIR/lib/brew_helpers.sh"

# ===== 配置文件路径 =====
CONFIG_DIR=$(cd "$(dirname "$0")"; pwd)  # 脚本所在目录
BREW_CONFIG_FILE="${CONFIG_DIR}/brew.conf.sh"

# ===== 通用工具函数 =====
# 幂等地更新 shell 配置文件
update_shell_config() {
    local section_name="$1"
    local config_content="$2"
    local rc_file="$HOME/.zshrc"
    local start_marker="# >>> ${section_name} (managed by macos-setup) >>>"
    local end_marker="# <<< ${section_name} (managed by macos-setup) <<<"

    # 如果存在旧块，先删除
    if grep -q "$start_marker" "$rc_file"; then
        sed -i '' "/$start_marker/,/$end_marker/d" "$rc_file"
    fi

    # 追加新块
    {
        echo ""
        echo "$start_marker"
        echo "$config_content"
        echo "$end_marker"
    } >> "$rc_file"
    success "${section_name} 环境配置已更新"
}

# ===== 预检模块 =====
precheck() {
    print_header "系统环境预检"

    [[ ! -f $BREW_CONFIG_FILE ]] && log_fatal "缺失 Homebrew 配置文件: $BREW_CONFIG_FILE"

    local os_version=$(sw_vers -productVersion)
    local major_version=$(echo $os_version | awk -F. '{print $1}')
    local minor_version=$(echo $os_version | awk -F. '{print $2}')
    local version_code=$(( major_version * 100 + minor_version ))
    
    [[ $version_code -lt 1015 ]] && log_fatal "需要 macOS Catalina (10.15) 或更高版本，当前版本：$os_version"

    local free_space=$(df -g / | tail -1 | awk '{print $4}')
    [[ $free_space -lt 15 ]] && log_fatal "磁盘空间不足15GB (剩余: ${free_space}GB)"

    if ! curl -sIm3 --retry 2 --connect-timeout 30 https://mirrors.ustc.edu.cn >/dev/null; then
        if ! ping -c2 223.5.5.5 &>/dev/null; then
            log_fatal "中科大源异常，网络连接失败，请检查网络设置"
        fi
    fi

    ! command -v brew &>/dev/null && log_fatal "brew 未安装，请先安装 Homebrew"
    success "系统环境预检通过"
}

# ===== Xcode CLI 工具安装 =====
install_xcode_cli() {
    print_header "安装 Xcode 命令行工具"
    
    if ! xcode-select -p &>/dev/null; then
        warning "正在安装 Xcode CLI 工具... 请在弹出的窗口中完成安装。"
        xcode-select --install
        
        local wait_count=0
        local max_wait=60 # 最多等待 60 * 5 = 300 秒
        until xcode-select -p &>/dev/null; do
            info "等待 Xcode CLI 安装完成... (${wait_count}/${max_wait})"
            sleep 5
            ((wait_count++))
            [[ $wait_count -gt $max_wait ]] && log_fatal "安装超时，请手动执行: xcode-select --install"
        done
        
        [[ -f /usr/bin/clang ]] || log_fatal "CLI 工具安装不完整"
    fi
    success "Xcode 命令行工具就绪"
}

# ===== Homebrew 配置 =====
configure_homebrew() {
    print_header "配置 Homebrew 镜像"

    local brew_config_content=$(cat <<'EOF'
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.ustc.edu.cn/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.ustc.edu.cn/homebrew-core.git"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"
export HOMEBREW_API_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles/api"
EOF
)
    update_shell_config "Homebrew Mirror" "$brew_config_content"
    eval "$brew_config_content" # 立即在当前会话生效

    warning "正在切换仓库远程地址..."
    git -C "$(brew --repo)" remote set-url origin "$HOMEBREW_BREW_GIT_REMOTE"
    
    local core_repo_path="$(brew --repo)/Library/Taps/homebrew/homebrew-core"
    if [ ! -d "$core_repo_path" ]; then
        warning "初始化 homebrew-core 仓库..."
        mkdir -p "$(dirname "$core_repo_path")"
        git clone "$HOMEBREW_CORE_GIT_REMOTE" "$core_repo_path"
    fi
    git -C "$core_repo_path" remote set-url origin "$HOMEBREW_CORE_GIT_REMOTE"
    
    warning "正在同步仓库配置 (带重试)..."
    local retry_count=3
    for ((i=1; i<=retry_count; i++)); do
        if brew update-reset -q; then
            success "Homebrew 镜像配置完成"
            return 0
        fi
        [[ $i -lt $retry_count ]] && warning "第 ${i} 次同步失败，10秒后重试..." && sleep 10
    done
    log_fatal "同步失败，已达最大重试次数"
}

# ===== 核心软件安装 =====
install_core_software() {
    print_header "安装核心开发工具"

    # 加载配置文件中的所有数组
    source "$BREW_CONFIG_FILE"

    bh_reset_summary

    local install_failed=false

    # 合并所有 Formulae 和 Casks 数组
    local all_formulae=(${(F)FORMULAE_@})
    local all_casks=(${(F)CASKS_@})

    if [[ ${#all_formulae[@]} -gt 0 ]]; then
        log_time_start "brew_formulae" "安装 ${#all_formulae[@]} 个 Homebrew Formulae"
        if bh_install_packages --formulae --retries 2 --label "Homebrew Formulae" "${all_formulae[@]}"; then
            log_time_end "brew_formulae" "Formulae 安装" "success"
        else
            install_failed=true
            log_time_end "brew_formulae" "Formulae 安装" "warn"
        fi
    else
        info "未在配置中检测到 Formulae 项"
    fi

    if [[ ${#all_casks[@]} -gt 0 ]]; then
        log_time_start "brew_casks" "安装 ${#all_casks[@]} 个 Homebrew Casks"
        if bh_install_packages --cask --retries 2 --label "Homebrew Casks" "${all_casks[@]}"; then
            log_time_end "brew_casks" "Cask 安装" "success"
        else
            install_failed=true
            log_time_end "brew_casks" "Cask 安装" "warn"
        fi
    else
        info "未在配置中检测到 Cask 项"
    fi

    bh_print_summary "核心软件安装报告"

    if [[ "$install_failed" == "true" ]]; then
        warning "部分 Homebrew 包安装失败，请查看上方失败列表并手动处理。"
    else
        success "核心软件安装完成"
    fi
}

# ===== 各语言环境配置 =====
install_node() {
    print_header "配置 Node.js 环境"
    brew list nvm &>/dev/null || brew install nvm
    mkdir -p ~/.nvm
    
    local nvm_config_content=$(cat <<'EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$(brew --prefix)/opt/nvm/nvm.sh" ] && \. "$(brew --prefix)/opt/nvm/nvm.sh"
[ -s "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm"
EOF
)
    update_shell_config "NVM" "$nvm_config_content"
    eval "$nvm_config_content"

    nvm install --lts --latest-npm
    npm config set registry https://registry.npmmirror.com
}

install_python() {
    print_header "配置 Python 环境"
    brew list python &>/dev/null || brew install python
    
    local python_config_content='export PATH="$(brew --prefix python)/libexec/bin:$PATH"'
    update_shell_config "Python Env" "$python_config_content"
    
    mkdir -p ~/.pip
    cat > ~/.pip/pip.conf <<EOF
[global]
index-url = https://mirrors.ustc.edu.cn/pypi/simple
trusted-host = mirrors.ustc.edu.cn
EOF
}

install_ruby() {
    print_header "配置 Ruby 环境"
    brew list ruby &>/dev/null || brew install ruby
    
    local ruby_config_content=$(cat <<'EOF'
export PATH="$(brew --prefix ruby)/bin:$PATH"
export LDFLAGS="-L$(brew --prefix ruby)/lib"
export CPPFLAGS="-I$(brew --prefix ruby)/include"
EOF
)
    update_shell_config "Ruby Env" "$ruby_config_content"
    
    gem sources --add https://mirrors.ustc.edu.cn/rubygems/ --remove https://rubygems.org/ > /dev/null
}

install_go() {
    print_header "配置 Go 环境"
    brew list go &>/dev/null || brew install go
    
    local go_config_content=$(cat <<'EOF'
export GOPATH="$HOME/Coding/go"
export PATH="$GOPATH/bin:$PATH"
export GOPROXY="https://goproxy.cn,direct"
EOF
)
    update_shell_config "Go Env" "$go_config_content"
    
    mkdir -p $HOME/Coding/go/{src,bin,pkg}
}

config_android_and_java() {
    print_header "配置 Android 和 Java 环境"
    local android_java_config_content=$(cat <<'EOF'
export JAVA_HOME="/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools"
EOF
)
    update_shell_config "Android & Java Env" "$android_java_config_content"
}

# ===== 安装后验证 =====
post_verification() {
    print_header "安装后验证"
    source ~/.zshrc # 确保加载所有新配置
    
    local has_warning=false
    local critical_cmds=(git brew node npm ruby go python pip python3 pip3)
    for cmd in "${critical_cmds[@]}"; do
        if ! command -v $cmd &>/dev/null; then
            warning "命令缺失: $cmd"
            has_warning=true
        fi
    done

    [[ -z "$(go env GOPROXY)" ]] && warning "GOPROXY 未正确配置" && has_warning=true
    [[ "$(npm config get registry)" != "https://registry.npmmirror.com/" ]] && warning "NPM 镜像源未配置" && has_warning=true
    [[ -z "$(gem sources -l | grep ustc)" ]] && warning "Ruby 镜像源未配置" && has_warning=true
    [[ "$(pip config get global.index-url)" != "https://mirrors.ustc.edu.cn/pypi/simple" ]] && warning "pip 镜像源未配置" && has_warning=true

    if [[ "$has_warning" == "false" ]]; then
        success "基础环境验证通过"
    else
        error "部分环境验证失败，请检查日志"
    fi
}

# ===== 主执行流程 =====
main() {
    precheck
    install_xcode_cli
    configure_homebrew
    
    # 安装各语言环境
    install_node
    install_python
    install_ruby
    install_go
    config_android_and_java
    
    # 安装核心软件
    install_core_software
    
    post_verification
    
    print_header "🎉 配置完成!"
    info "建议后续操作:"
    info "1. ${BOLD}完全重启终端${NC} 或执行 $(highlight 'source ~/.zshrc') 来刷新环境。"
    info "2. 检查新的配置文件位置："
    info "   - $(highlight "$BREW_CONFIG_FILE")"
}

# 启动主流程
main