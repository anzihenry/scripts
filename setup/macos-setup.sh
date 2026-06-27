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

main() {
    initialize_setup_context
    run_setup_workflow
}

main
