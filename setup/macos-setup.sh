#!/bin/zsh
# filepath: setup/macos-setup.sh

set -e                            # 错误立即退出
set -u                            # 未定义变量视为错误
set -o pipefail                   # 管道错误捕获

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 引入工具库（提供运行时 helper 与日志 fallback）
source "$SCRIPT_DIR/../lib/colors.sh"
source "$SCRIPT_DIR/../lib/utils.sh"
source "$SCRIPT_DIR/lib/brew_helpers.sh"
source "$SCRIPT_DIR/../lib/config_writer.sh"
source "$SCRIPT_DIR/lib/homebrew_config.sh"
source "$SCRIPT_DIR/lib/setup_runtime.sh"
source "$SCRIPT_DIR/lib/setup_lang_env.sh"
source "$SCRIPT_DIR/lib/setup_postcheck.sh"

main() {
    parse_setup_options "$@" || return $?
    if [[ "$SETUP_HELP" == true ]]; then
        printf '用法: macos-setup.sh [--dry-run] [--modules node,python,ruby,go,android,packages]\n说明: 默认选择全部模块；预览不安装、不联网、不写配置。\n'
        return 0
    fi
    [[ "$SETUP_DRY_RUN" != true ]] || { preview_setup; return $?; }
    require_supported_macos || exit 1
    initialize_setup_context || return 1
    resource_lock_acquire "setup-packages:${HOME:A}" || return 1
    homebrew_resource_lock || return 1
    run_setup_workflow
}

trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP
main "$@" || exit $?
