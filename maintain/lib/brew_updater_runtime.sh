#!/bin/zsh
# filepath: maintain/lib/brew_updater_runtime.sh

confirm_run() {
    [[ "$DRY_RUN" == "true" || "$ASSUME_YES" == "true" ]] && return 0

    if ! confirm "将执行 Homebrew 维护操作，是否继续" "N"; then
        warning "已取消执行"
        exit 0
    fi
}

announce_brew_updater_context() {
    print_header "Homebrew 维护工具"
    info "错误日志位置: $ERROR_LOG"
    if [[ "$FORCE_CASKS" == "true" ]]; then
        warning "已启用 --force，将包含默认排除的 Cask"
    fi
}

run_homebrew_update() {
    print_header "步骤 1：更新 Homebrew 元数据"
    run_timed_command_or_fail \
        "brew_update" \
        "执行 brew update" \
        "brew update 完成" \
        "brew update 失败" \
        "brew update 执行失败" \
        brew update
}

run_formulae_upgrade() {
    print_header "步骤 2：更新 Formulae"
    run_timed_command_or_fail \
        "brew_upgrade_formulae" \
        "执行 brew upgrade --formula" \
        "Formulae 更新完成" \
        "Formulae 更新失败" \
        "brew upgrade 执行失败" \
        brew upgrade --formula
}

run_cleanup() {
    print_header "步骤 4：清理缓存"
    run_timed_command_or_fail \
        "brew_cleanup" \
        "执行 brew cleanup" \
        "brew cleanup 完成" \
        "brew cleanup 失败" \
        "brew cleanup 执行失败" \
        brew cleanup
}

run_optional_formulae_upgrade() {
    if [[ "$SKIP_FORMULAE" == "true" ]]; then
        warning "已跳过 Formulae 更新"
        return 0
    fi

    run_formulae_upgrade
}

run_optional_cask_upgrades() {
    if [[ "$SKIP_CASKS" == "true" ]]; then
        warning "已跳过 Cask 更新"
        return 0
    fi

    run_cask_upgrades
}

run_optional_cleanup() {
    if [[ "$SKIP_CLEANUP" == "true" ]]; then
        warning "已跳过缓存清理"
        return 0
    fi

    run_cleanup
}

run_brew_updater_workflow() {
    run_homebrew_update
    run_optional_formulae_upgrade
    run_optional_cask_upgrades
    run_optional_cleanup
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
