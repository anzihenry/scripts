#!/bin/zsh

job_launchctl_session() {
    printf "gui/%s" "$(id -u)"
}

launchctl_bootstrap() {
    local plist_path="$1"
    local label="$2"
    local dry_run="$3"
    local current_session
    current_session="$(job_launchctl_session)"

    if [[ "$dry_run" == "1" ]]; then
        info "(dry-run) 将执行: launchctl bootout ${current_session}/${label} (忽略不存在的错误)"
        info "(dry-run) 将执行: launchctl bootstrap ${current_session} ${plist_path}"
        info "(dry-run) 将执行: launchctl enable ${current_session}/${label}"
        return
    fi

    if launchctl print "${current_session}/${label}" >/dev/null 2>&1; then
        info "卸载已存在的任务 ${label}"
        launchctl bootout "${current_session}/${label}" >/dev/null 2>&1 || true
    fi
    info "加载新任务 ${label}"
    launchctl bootstrap "${current_session}" "$plist_path"
    info "启用任务 ${label}"
    launchctl enable "${current_session}/${label}"
}

launchctl_bootout() {
    local label="$1"
    local dry_run="$2"
    local current_session
    current_session="$(job_launchctl_session)"

    if [[ "$dry_run" == "1" ]]; then
        info "(dry-run) 将执行: launchctl bootout ${current_session}/${label}"
        return
    fi

    if launchctl print "${current_session}/${label}" >/dev/null 2>&1; then
        info "卸载任务 ${label}"
        launchctl bootout "${current_session}/${label}"
    else
        warning "未检测到正在运行的任务"
    fi
}

launchctl_disable() {
    local label="$1"
    local dry_run="$2"
    local current_session
    current_session="$(job_launchctl_session)"

    if [[ "$dry_run" == "1" ]]; then
        info "(dry-run) 将执行: launchctl disable ${current_session}/${label}"
        return
    fi

    launchctl disable "${current_session}/${label}" || warning "禁用命令返回非零"
}

show_status() {
    local job_name="$1"
    local label
    label="$(get_label "$job_name")"
    local current_session
    current_session="$(job_launchctl_session)"

    info "查看任务 ${label} 状态..."
    if launchctl print "${current_session}/${label}" >/dev/null 2>&1; then
        launchctl print "${current_session}/${label}" | sed 's/^/    /'
        success "任务处于已加载状态"
    else
        warning "任务未加载，可使用 enable 或 create --no-load false 重新加载"
    fi
}

list_jobs() {
    info "列出当前用户的脚本任务..."
    local count=0
    local plist
    for plist in "$LAUNCH_AGENTS_DIR"/${JOB_LABEL_PREFIX}.*.plist(N); do
        [[ -f "$plist" ]] || continue
        local job_name
        job_name="${plist##*.job.}"
        job_name="${job_name%.plist}"
        printf "  - %s (%s)\n" "$job_name" "$plist"
        # 注意：不要用 ((count++))——count 从 0 起时该算术表达式返回假，
        # 在 set -e 下会触发 errexit 提前退出，导致 job list 返回非零。
        count=$((count + 1))
    done
    if (( count == 0 )); then
        warning "未找到任何 ${JOB_LABEL_PREFIX} 前缀的任务"
    fi
}
