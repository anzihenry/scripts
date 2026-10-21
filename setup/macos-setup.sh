#!/bin/zsh
# filepath: setup/macos-setup.sh

set -e                            # 错误立即退出
set -u                            # 未定义变量视为错误
set -o pipefail                   # 管道错误捕获

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 引入工具库（提供运行时 helper 与日志 fallback）
source "$SCRIPT_DIR/../lib/utils.sh"
source "$SCRIPT_DIR/lib/brew_helpers.sh"
source "$SCRIPT_DIR/lib/config_writer.sh"
source "$SCRIPT_DIR/lib/homebrew_config.sh"
source "$SCRIPT_DIR/lib/setup_runtime.sh"
source "$SCRIPT_DIR/lib/setup_lang_env.sh"
source "$SCRIPT_DIR/lib/setup_postcheck.sh"

main() {
    case "${1:-}" in
        -h|--help|help)
            printf '用法: macos-setup.sh\n说明: 安装开发环境和软件包；需要 macOS 14+。\n'
            return 0
            ;;
        '') ;;
        *) error "未知参数: $1"; return 1 ;;
    esac
    require_supported_macos || exit 1
    initialize_setup_context
    run_setup_workflow
}

main "$@"
