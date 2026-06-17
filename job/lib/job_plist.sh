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

    local args=("$script_path" "$@")
    local xml="    <key>ProgramArguments</key>\n    <array>\n"
    local arg
    for arg in "${args[@]}"; do
        xml+="      <string>$(xml_escape "$arg")</string>\n"
    done
    xml+="    </array>\n"
    printf "%s" "$xml"
}

compose_schedule_block() {
    local interval_minutes="$1"
    local at_time="$2"
    local weekday="$3"
    local xml=""

    if [[ -n "$interval_minutes" ]]; then
        local seconds=$((interval_minutes * 60))
        if (( seconds <= 0 )); then
            error "--interval 必须为正整数"
            exit 1
        fi
        xml+="    <key>StartInterval</key>\n    <integer>${seconds}</integer>\n"
    fi

    if [[ -n "$at_time" ]]; then
        if [[ ! "$at_time" =~ ^[0-2][0-9]:[0-5][0-9]$ ]]; then
            error "--at 格式必须为 HH:MM"
            exit 1
        fi
        local hour="${at_time%%:*}"
        local minute="${at_time##*:}"
        xml+="    <key>StartCalendarInterval</key>\n    <dict>\n      <key>Hour</key>\n      <integer>${hour#0}</integer>\n      <key>Minute</key>\n      <integer>${minute#0}</integer>\n"
        if [[ -n "$weekday" ]]; then
            if ! [[ "$weekday" =~ ^[0-6]$ ]]; then
                error "--weekday 取值范围 0-6"
                exit 1
            fi
            xml+="      <key>Weekday</key>\n      <integer>${weekday}</integer>\n"
        fi
        xml+="    </dict>\n"
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

    local xml_header="<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<dict>\n    <key>Label</key>\n    <string>${label}</string>\n"
    local xml_footer="</dict>\n</plist>\n"
    local xml_body="${program_block}    <key>WorkingDirectory</key>\n    <string>$(xml_escape "$working_dir")</string>\n    <key>StandardOutPath</key>\n    <string>$(xml_escape "$stdout_path")</string>\n    <key>StandardErrorPath</key>\n    <string>$(xml_escape "$stderr_path")</string>\n    <key>RunAtLoad</key>\n    <true/>\n"

    if [[ "$keepalive" == "1" ]]; then
        xml_body+="    <key>KeepAlive</key>\n    <true/>\n"
    fi

    xml_body+="$schedule_block"

    if [[ "$disabled" == "1" ]]; then
        xml_body+="    <key>Disabled</key>\n    <true/>\n"
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
