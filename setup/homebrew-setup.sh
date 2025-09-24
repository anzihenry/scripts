#!/bin/zsh

# ===== 初始化配置 =====
exec > >(tee -a setup.log) 2>&1  # 启用日志记录
set -e                            # 错误立即退出
set -o pipefail                   # 管道错误捕获

# 配置颜色输出
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
success() { echo -e "${GREEN}[✓] $1${NC}"; }
warning() { echo -e "${YELLOW}[!] $1${NC}"; }
error() { echo -e "${RED}[✗] $1${NC}"; exit 1; }

# ===== 配置文件路径 =====
CONFIG_DIR=$(cd "$(dirname "$0")"; pwd)  # 脚本所在目录

# ===== 预检模块 =====
precheck() {
    echo -e "\n${GREEN}=== 系统环境预检 ===${NC}"

    # 系统版本检查 (macOS 10.15+) - 修正版本判断逻辑
    local os_version=$(sw_vers -productVersion)
    local major_version=$(echo $os_version | awk -F. '{print $1}')
    local minor_version=$(echo $os_version | awk -F. '{print $2}')
    
    # 转换为可比较的数值（10.15 → 1015，11.0 → 1100）
    local version_code=$(( major_version * 100 + minor_version ))
    
    if [[ $version_code -lt 1015 ]]; then
        error "需要 macOS Catalina (10.15) 或更高版本，当前版本：$os_version"
    fi

    # 磁盘空间检查 (15GB+)
    local free_space=$(df -g / | tail -1 | awk '{print $4}')
    [[ $free_space -lt 15 ]] && error "磁盘空间不足15GB (剩余: ${free_space}GB)"

    # 网络连通性检查
    if ! curl -sIm3 --retry 2 --connect-timeout 30 https://mirrors.ustc.edu.cn >/dev/null; then
        if ! ping -c2 223.5.5.5 &>/dev/null; then
            error "中科大源异常，网络连接失败，请检查网络设置"
        fi
    fi

    success "系统环境预检通过"
}

# ===== Xcode CLI 工具安装 =====
install_xcode_cli() {
    echo -e "\n${GREEN}=== 安装 Xcode 命令行工具 ===${NC}"
    
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
            [[ $wait_count -gt $max_wait ]] && error "安装超时，请手动执行: xcode-select --install"
        done
        
        # 验证编译器存在
        [[ -f /usr/bin/clang ]] || error "CLI 工具安装不完整"
    fi
    success "Xcode 命令行工具就绪"
}

# ===== Homebrew 安装 =====
install_homebrew() {
    echo -e "\n${GREEN}=== 安装 Homebrew ===${NC}"

    if ! command -v brew &>/dev/null; then
        warning "正在尝试官方源安装..."
        
        # 获取架构信息
        local BREW_PREFIX
        if [[ $(uname -m) == "arm64" ]]; then
            BREW_PREFIX="/opt/homebrew"
        else
            BREW_PREFIX="/usr/local"
        fi

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
                error "Homebrew 安装失败，请检查网络连接"
            }
        fi

        # 基础环境配置
        if ! grep -q "# Homebrew Basic" ~/.zshrc; then
            success "正在向 ~/.zshrc 添加 Homebrew 配置..."
            {
                echo ""
                echo "# Homebrew Basic (Added by script)"
                echo "export PATH=\"${BREW_PREFIX}/bin:${BREW_PREFIX}/sbin:\$PATH\""
                echo "eval \"\$(${BREW_PREFIX}/bin/brew shellenv)\""
            } >> ~/.zshrc
        else
            warning "检测到已存在 Homebrew 配置，跳过添加。"
        fi

        # 立即生效配置
        source ~/.zshrc
        eval "$(${BREW_PREFIX}/bin/brew shellenv)"
    fi

    # 验证安装
    if ! command -v brew &>/dev/null || ! brew --version &>/dev/null; then
        error "Homebrew 安装验证失败，请检查 ~/.zshrc 配置或重新运行脚本。"
    fi

    success "Homebrew 安装完成 (版本: $(brew --version | head -n1))"
}

# ===== 主执行流程 =====
main() {
    precheck
    install_xcode_cli
    install_homebrew
    
    echo -e "\n${GREEN}=== 安装完成! ===${NC}"
    echo "建议后续操作:"
    echo "1. 执行 source ~/.zshrc 刷新环境"
}

# 启动主流程
main