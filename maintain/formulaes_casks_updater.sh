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

command_preview() {
    printf '%s' "${(q-)@}"
}

run_command() {
    if [[ "$DRY_RUN" == "true" ]]; then
        print_code "$(command_preview "$@")"
        return 0
    fi
    "$@"
}

confirm_run() {
    [[ "$DRY_RUN" == "true" || "$ASSUME_YES" == "true" ]] && return 0

    if ! confirm "将执行 Homebrew 维护操作，是否继续" "N"; then
        warning "已取消执行"
        exit 0
    fi
}

run_homebrew_update() {
    print_header "步骤 1：更新 Homebrew 元数据"
    log_time_start "brew_update" "执行 brew update"
    if ! run_command brew update; then
        log_time_end "brew_update" "brew update 失败" "error"
        log_fatal "brew update 执行失败"
    fi
    log_time_end "brew_update" "brew update 完成"
}

run_formulae_upgrade() {
    print_header "步骤 2：更新 Formulae"
    log_time_start "brew_upgrade_formulae" "执行 brew upgrade"
    if ! run_command brew upgrade; then
        log_time_end "brew_upgrade_formulae" "Formulae 更新失败" "error"
        log_fatal "brew upgrade 执行失败"
    fi
    log_time_end "brew_upgrade_formulae" "Formulae 更新完成"
}

run_cleanup() {
    print_header "步骤 4：清理缓存"
    log_time_start "brew_cleanup" "执行 brew cleanup"
    if ! run_command brew cleanup; then
        log_time_end "brew_cleanup" "brew cleanup 失败" "error"
        log_fatal "brew cleanup 执行失败"
    fi
    log_time_end "brew_cleanup" "brew cleanup 完成"
}

print_summary() {
    print_header "维护总结"
    print_table_row "Dry Run" "$DRY_RUN"
    print_table_row "错误日志" "$ERROR_LOG"
    print_table_row "已更新 Cask" "${#UPDATED_CASKS[@]}"
    print_table_row "已跳过 Cask" "${#SKIPPED_CASKS[@]}"
    print_table_row "失败 Cask" "${#FAILED_CASKS[@]}"

    if [[ ${#SKIPPED_CASKS[@]} -gt 0 ]]; then
        warning "已排除的 Cask: ${SKIPPED_CASKS[*]}"
    fi

    if [[ ${#FAILED_CASKS[@]} -gt 0 ]]; then
        error "以下 Cask 更新失败: ${FAILED_CASKS[*]}"
        return 1
    fi

    success "Homebrew 维护完成"
    return 0
}

main() {
    initialize_brew_updater_context
    parse_brew_updater_args "$@"
    require_command brew

    print_header "Homebrew 维护工具"
    info "错误日志位置: $ERROR_LOG"
    [[ "$FORCE_CASKS" == "true" ]] && warning "已启用 --force，将包含默认排除的 Cask"

    confirm_run
    run_homebrew_update

    if [[ "$SKIP_FORMULAE" == "true" ]]; then
        warning "已跳过 Formulae 更新"
    else
        run_formulae_upgrade
    fi

    if [[ "$SKIP_CASKS" == "true" ]]; then
        warning "已跳过 Cask 更新"
    else
        run_cask_upgrades
    fi

    if [[ "$SKIP_CLEANUP" == "true" ]]; then
        warning "已跳过缓存清理"
    else
        run_cleanup
    fi

    print_summary
}

main "$@"
