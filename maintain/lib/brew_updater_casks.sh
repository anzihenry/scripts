#!/bin/zsh
# filepath: maintain/lib/brew_updater_casks.sh

append_brew_update_error_log() {
    local cask="$1"
    local message="$2"
    local timestamp
    timestamp="$(date "+%Y-%m-%d %H:%M:%S")"
    printf '%s 更新失败: %s (%s)\n' "$timestamp" "$cask" "$message" >> "$ERROR_LOG"
}

get_outdated_casks() {
    local output
    local line
    local cask
    local -a valid_casks=()

    output="$(brew outdated --cask --greedy 2>/dev/null || true)"
    [[ -z "$output" ]] && return 0

    # brew outdated 偶尔会把环境提示写到 stdout。不能把任意非空行的首列
    # 都当作 Cask；只有 brew list 能确认已安装的 token 才进入升级队列。
    for line in "${(@f)output}"; do
        [[ -z "${line//[[:space:]]/}" ]] && continue
        cask="${line%%[[:space:]]*}"
        cask="${(L)cask}"

        if brew list --cask "$cask" >/dev/null 2>&1; then
            valid_casks+=("$cask")
        else
            warning "忽略 brew outdated 的非 Cask 输出: $cask" >&2
        fi
    done

    [[ ${#valid_casks[@]} -eq 0 ]] && return 0
    printf '%s\n' "${(ou)valid_casks[@]}"
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

run_cask_upgrade() {
    local cask="$1"
    local timer_key="cask_${cask//[^A-Za-z0-9]/_}"

    if ! cask_exists "$cask"; then
        FAILED_CASKS+=("$cask")
        append_brew_update_error_log "$cask" "Cask 不存在或已失效"
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
    append_brew_update_error_log "$cask" "brew upgrade --cask 执行失败"
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
        [[ -z "$cask" ]] && continue
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
