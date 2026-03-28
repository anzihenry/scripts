#!/bin/zsh
# filepath: maintain/formulaes_casks_updater.sh

set -e
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/colors.sh"

typeset -ga EXCLUDED_CASKS=(
    "microsoft-.*"
    "android-studio"
    "visual-studio-code"
    "docker-desktop"
    "iterm2"
    "google-chrome"
    "feishu"
    "lark"
)

if [[ -n "${MACOS_SCRIPTS_LOG_DIR:-}" ]]; then
    mkdir -p "$MACOS_SCRIPTS_LOG_DIR"
    ERROR_LOG="$MACOS_SCRIPTS_LOG_DIR/brew_update_errors.log"
else
    ERROR_LOG="$SCRIPT_DIR/brew_update_errors.log"
fi

DRY_RUN="false"
ASSUME_YES="false"
FORCE_CASKS="false"
SKIP_FORMULAE="false"
SKIP_CASKS="false"
SKIP_CLEANUP="false"

typeset -ga UPDATED_CASKS=()
typeset -ga SKIPPED_CASKS=()
typeset -ga FAILED_CASKS=()

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

require_command() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || log_fatal "缺少命令: $cmd"
}

append_error_log() {
    local cask="$1"
    local message="$2"
    local timestamp
    timestamp="$(date "+%Y-%m-%d %H:%M:%S")"
    printf '%s 更新失败: %s (%s)\n' "$timestamp" "$cask" "$message" >> "$ERROR_LOG"
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

get_outdated_casks() {
    local output
    output="$(brew outdated --cask --greedy 2>/dev/null || true)"
    [[ -z "$output" ]] && return 0
    printf '%s\n' "$output" | awk '{print tolower($1)}' | sort -u
}

cask_exists() {
    local cask="$1"
    brew info --cask "$cask" >/dev/null 2>&1
}

is_excluded_cask() {
    local cask="$1"
    local pattern

    [[ "$FORCE_CASKS" == "true" ]] && return 1

    for pattern in "${EXCLUDED_CASKS[@]}"; do
        if [[ "$cask" =~ ${pattern} ]]; then
            return 0
        fi
    done

    return 1
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN="true"
                ;;
            --yes|-y)
                ASSUME_YES="true"
                ;;
            --force)
                FORCE_CASKS="true"
                ;;
            --skip-formulae)
                SKIP_FORMULAE="true"
                ;;
            --skip-casks)
                SKIP_CASKS="true"
                ;;
            --skip-cleanup)
                SKIP_CLEANUP="true"
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_fatal "未知参数: $1"
                ;;
        esac
        shift
    done
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

run_cask_upgrade() {
    local cask="$1"
    local timer_key="cask_${cask//[^A-Za-z0-9]/_}"

    if ! cask_exists "$cask"; then
        FAILED_CASKS+=("$cask")
        append_error_log "$cask" "Cask 不存在或已失效"
        error "Cask 不存在或已失效: $cask"
        return 1
    fi

    log_time_start "$timer_key" "升级 Cask: $cask"
    if run_command brew upgrade --cask "$cask"; then
        UPDATED_CASKS+=("$cask")
        log_time_end "$timer_key" "Cask 更新完成: $cask"
        return 0
    fi

    FAILED_CASKS+=("$cask")
    append_error_log "$cask" "brew upgrade --cask 执行失败"
    log_time_end "$timer_key" "Cask 更新失败: $cask" "error"
    return 1
}

run_cask_upgrades() {
    local -a outdated_casks=()
    local -a filtered_casks=()
    local cask
    local index=1

    print_header "步骤 3：更新 Cask"
    info "正在检测可更新的 Cask 应用..."

    outdated_casks=("${(@f)$(get_outdated_casks)}")
    if [[ ${#outdated_casks[@]} -eq 0 ]]; then
        warning "没有检测到需要更新的 Cask 应用"
        return 0
    fi

    for cask in "${outdated_casks[@]}"; do
        if is_excluded_cask "$cask"; then
            SKIPPED_CASKS+=("$cask")
            continue
        fi
        filtered_casks+=("$cask")
    done

    warning "发现 ${#outdated_casks[@]} 个可更新 Cask，排除 ${#SKIPPED_CASKS[@]} 个"

    if [[ ${#filtered_casks[@]} -eq 0 ]]; then
        warning "过滤后没有需要更新的 Cask"
        return 0
    fi

    for cask in "${filtered_casks[@]}"; do
        print_step "$index" "${#filtered_casks[@]}" "处理 Cask: $cask"
        run_cask_upgrade "$cask" || true
        ((index++))
    done
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
    parse_args "$@"
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