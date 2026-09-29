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
    local outdated_status=0
    local -a valid_casks=()

    # 不能吞掉 brew 的退出码：网络故障/brew 异常时会返回非零，
    # 若与「无更新」一样 return 0，会把失败误报成「没有需要更新的 Cask」。
    set +e
    output="$(brew outdated --cask --greedy 2> /dev/null)"
    outdated_status=$?
    set -e
    if [[ $outdated_status -ne 0 ]]; then
        warning "brew outdated --cask 执行失败（退出码 $outdated_status），本次跳过 Cask 更新检测"
        return 1
    fi
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
        # dry-run 下 run_command 只预览、并未真正升级，不能计入「已更新」。
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_time_end "$timer_key" "Cask 更新预览: $cask"
        else
            UPDATED_CASKS+=("$cask")
            log_time_end "$timer_key" "Cask 更新完成: $cask"
        fi
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

    # 捕获返回值：get_outdated_casks 在 brew 失败时返回非零。直接写
    # `outdated_casks=("${(@f)$(get_outdated_casks)}")` 在 set -e 下会
    # 因赋值语句继承失败状态而终止；同时也不能把失败当作「无更新」。
    local outdated_output="" outdated_status=0
    set +e
    outdated_output="$(get_outdated_casks)"
    outdated_status=$?
    set -e
    if [[ $outdated_status -ne 0 ]]; then
        warning "Cask 更新检测失败，跳过本步骤（其余维护步骤继续）"
        return 0
    fi

    outdated_casks=("${(@f)outdated_output}")
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
