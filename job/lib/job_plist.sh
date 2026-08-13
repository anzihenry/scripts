#!/bin/zsh

xml_escape() {
    local input="${1:-}"
    local escaped="$input"
    local replacements=(
        '&' '&amp;'
        '<' '&lt;'
        '>' '&gt;'
        '"' '&quot;'
        "'" '&apos;'
    )
    local index original replacement
    for ((index = 1; index <= ${#replacements[@]}; index += 2)); do
        original="${replacements[index]}"
        replacement="${replacements[index + 1]}"
        escaped="${escaped//$original/$replacement}"
    done
    printf "%s" "$escaped"
}

ensure_job_directories() {
    mkdir -p "$LAUNCH_AGENTS_DIR"
    mkdir -p "$LOG_BASE_DIR"
}

compose_program_arguments() {
    local script_path="$1"
    shift

    local nl=$'\n'
    local args=("$script_path" "$@")
    local xml="    <key>ProgramArguments</key>${nl}    <array>${nl}"
    local arg
    for arg in "${args[@]}"; do
        xml+="      <string>$(xml_escape "$arg")</string>${nl}"
    done
    xml+="    </array>${nl}"
    printf "%s" "$xml"
}

compose_schedule_block() {
    local interval_minutes="$1"
    local at_time="$2"
    local weekday="$3"
    local nl=$'\n'
    local xml=""

    if [[ -n "$interval_minutes" ]]; then
        local seconds=$((interval_minutes * 60))
        if (( seconds <= 0 )); then
            error "--interval 必须为正整数"
            exit 1
        fi
        xml+="    <key>StartInterval</key>${nl}    <integer>${seconds}</integer>${nl}"
    fi

    if [[ -n "$at_time" ]]; then
        if [[ ! "$at_time" =~ ^[0-2][0-9]:[0-5][0-9]$ ]]; then
            error "--at 格式必须为 HH:MM"
            exit 1
        fi
        local hour="${at_time%%:*}"
        local minute="${at_time##*:}"
        xml+="    <key>StartCalendarInterval</key>${nl}    <dict>${nl}      <key>Hour</key>${nl}      <integer>${hour#0}</integer>${nl}      <key>Minute</key>${nl}      <integer>${minute#0}</integer>${nl}"
        if [[ -n "$weekday" ]]; then
            if ! [[ "$weekday" =~ ^[0-6]$ ]]; then
                error "--weekday 取值范围 0-6"
                exit 1
            fi
            xml+="      <key>Weekday</key>${nl}      <integer>${weekday}</integer>${nl}"
        fi
        xml+="    </dict>${nl}"
    fi

    if [[ -z "$xml" ]]; then
        error "需要指定 --interval 或 --at"
        exit 1
    fi
    printf "%s" "$xml"
}

compose_plist() {
    local label="$1"
    local working_dir="$2"
    local stdout_path="$3"
    local stderr_path="$4"
    local keepalive="$5"
    local disabled="$6"
    local schedule_block="$7"
    local program_block="$8"

    local nl=$'\n'
    local xml_header="<?xml version=\"1.0\" encoding=\"UTF-8\"?>${nl}<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">${nl}<plist version=\"1.0\">${nl}<dict>${nl}    <key>Label</key>${nl}    <string>${label}</string>${nl}"
    local xml_footer="</dict>${nl}</plist>${nl}"
    # 命令替换 $(...) 会剥离子命令输出的尾随换行，这里在拼接点补回，
    # 避免 </array>/</dict> 与后续标签粘连成一行。
    local xml_body="${program_block}${nl}    <key>WorkingDirectory</key>${nl}    <string>$(xml_escape "$working_dir")</string>${nl}    <key>StandardOutPath</key>${nl}    <string>$(xml_escape "$stdout_path")</string>${nl}    <key>StandardErrorPath</key>${nl}    <string>$(xml_escape "$stderr_path")</string>${nl}    <key>RunAtLoad</key>${nl}    <true/>${nl}"

    if [[ "$keepalive" == "1" ]]; then
        xml_body+="    <key>KeepAlive</key>${nl}    <true/>${nl}"
    fi

    xml_body+="${schedule_block}${nl}"

    if [[ "$disabled" == "1" ]]; then
        xml_body+="    <key>Disabled</key>${nl}    <true/>${nl}"
    fi

    printf "%s%s%s" "$xml_header" "$xml_body" "$xml_footer"
}

backup_existing_plist() {
    local plist_path="$1"
    local backup_dir="${plist_path}.bak"
    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    local backup_path="${backup_dir}/$(basename "$plist_path").${timestamp}"
    cp "$plist_path" "$backup_path"
    info "已备份旧版本: ${backup_path}"
}

write_plist_file() {
    local plist_path="$1"
    local plist_content="$2"
    printf "%s" "$plist_content" > "$plist_path"
    plutil -lint "$plist_path" >/dev/null
}
