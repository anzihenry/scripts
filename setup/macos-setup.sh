#!/bin/zsh
# filepath: setup/macos-setup.sh

set -e                            # 错误立即退出
set -o pipefail                   # 管道错误捕获

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 引入工具库（提供运行时 helper 与日志 fallback）
source "$SCRIPT_DIR/../lib/utils.sh"
source "$SCRIPT_DIR/lib/brew_helpers.sh"
source "$SCRIPT_DIR/lib/config_writer.sh"
source "$SCRIPT_DIR/lib/homebrew_config.sh"
source "$SCRIPT_DIR/lib/setup_shell_config.sh"
source "$SCRIPT_DIR/lib/setup_runtime.sh"
source "$SCRIPT_DIR/lib/setup_lang_env.sh"
source "$SCRIPT_DIR/lib/setup_postcheck.sh"

# ===== 初始化配置 =====
SETUP_LOG_FILE="$(prepare_log_file_path "macos-setup.log" "$SCRIPT_DIR/setup.log")"
enable_log_capture "$SETUP_LOG_FILE"

# ===== 配置文件路径 =====
CONFIG_DIR=$(cd "$(dirname "$0")"; pwd)  # 脚本所在目录
DEFAULT_BREW_CONFIG_FILE="${CONFIG_DIR}/brew.conf.sh"

if [[ -n "${MACOS_SCRIPTS_CONFIG_DIR:-}" ]]; then
    mkdir -p "$MACOS_SCRIPTS_CONFIG_DIR"
    BREW_CONFIG_FILE="${MACOS_SCRIPTS_CONFIG_DIR}/brew.conf.sh"
else
    BREW_CONFIG_FILE="$DEFAULT_BREW_CONFIG_FILE"
fi

# ===== 主执行流程 =====
main() {
    precheck
    ensure_xcode_cli_installed
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

    print_setup_completion
}

# 启动主流程
main
