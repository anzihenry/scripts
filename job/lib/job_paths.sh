#!/bin/zsh

JOB_LABEL_PREFIX="com.biucing.scripts.job"
# 支持环境变量覆盖，便于测试隔离与自定义部署位置
LAUNCH_AGENTS_DIR="${MACOS_SCRIPTS_LAUNCH_AGENTS_DIR:-${HOME}/Library/LaunchAgents}"
if [[ -n "${MACOS_SCRIPTS_LOG_DIR:-}" ]]; then
    LOG_BASE_DIR="${MACOS_SCRIPTS_LOG_DIR}/jobs"
else
    LOG_BASE_DIR="${HOME}/Library/Logs/scripts-jobs"
fi

resolve_path() {
    local path="$1"
    if [[ "$path" == /* ]]; then
        printf "%s" "$path"
        return
    fi

    local dir_part="${path:h}"
    local base_part="${path:t}"
    local resolved_dir
    if ! resolved_dir="$(cd "$PWD" && cd "$dir_part" 2>/dev/null && pwd)"; then
        error "无法解析路径: $path"
        exit 1
    fi

    printf "%s/%s" "$resolved_dir" "$base_part"
}

resolve_directory() {
    local path="$1"
    local resolved
    resolved="$(resolve_path "$path")"
    if [[ ! -d "$resolved" ]]; then
        error "目录不存在: $resolved"
        exit 1
    fi
    printf "%s" "$resolved"
}

get_plist_path() {
    local job_name="$1"
    printf "%s/%s.%s.plist" "$LAUNCH_AGENTS_DIR" "$JOB_LABEL_PREFIX" "$job_name"
}

get_label() {
    local job_name="$1"
    printf "%s.%s" "$JOB_LABEL_PREFIX" "$job_name"
}

sanitize_log_path() {
    local path="$1"
    if [[ -z "$path" ]]; then
        printf "%s" "$path"
        return
    fi

    local dir
    dir="$(dirname "$path")"
    mkdir -p "$dir"
    printf "%s" "$path"
}
