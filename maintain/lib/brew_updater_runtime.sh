#!/bin/zsh
# filepath: maintain/lib/brew_updater_runtime.sh

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
