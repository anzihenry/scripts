#!/bin/zsh
# filepath: maintain/formulaes_casks_updater.sh

set -e
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/colors.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/utils.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/brew_updater_args.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/brew_updater_casks.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/command_runtime.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/brew_updater_runtime.sh"

usage() {
    cat <<'EOF'
用法: formulaes_casks_updater.sh [选项]

选项:
    --dry-run         仅展示将执行的命令，不实际更新
    --yes             跳过执行前确认
    --force           包含默认排除的 Cask 一并升级
    --skip-formulae   跳过 brew upgrade
    --skip-casks      跳过 Cask 检测与升级
    --skip-cleanup    跳过 brew cleanup
    -h, --help        显示帮助

说明:
    失败的 Cask 会追加记录到 brew_update_errors.log。
    若通过 macos-scripts 安装态运行，默认写入 ~/Library/Logs/macos-scripts/。
EOF
}

main() {
    initialize_brew_updater_context
    parse_brew_updater_args "$@"
    require_command brew

    announce_brew_updater_context
    confirm_run
    run_brew_updater_workflow
    print_summary
}

main "$@"
