#!/bin/zsh
# filepath: setup/lib/config_writer.sh

ensure_parent_dir() {
    local target_path="$1"
    local parent_dir="${target_path:h}"
    mkdir -p "$parent_dir"
}

write_managed_block() {
    local target_file="$1"
    local section_name="$2"
    local manager_name="$3"
    local content="$4"
    local dry_run="${5:-false}"
    local start_marker="# >>> ${section_name} (managed by ${manager_name}) >>>"
    local end_marker="# <<< ${section_name} (managed by ${manager_name}) <<<"

    if [[ "$dry_run" == "true" ]]; then
        info "[dry-run] 将更新 $target_file 中的 ${section_name} 配置块"
        print_code "$start_marker"
        printf '%s\n' "$content"
        print_code "$end_marker"
        return 0
    fi

    ensure_parent_dir "$target_file"
    touch "$target_file"

    if grep -Fq "$start_marker" "$target_file"; then
        sed -i '' "\\|$start_marker|,\\|$end_marker|d" "$target_file"
    fi

    {
        echo ""
        echo "$start_marker"
        echo "$content"
        echo "$end_marker"
    } >> "$target_file"
}

write_managed_file() {
    local target_file="$1"
    local content="$2"
    local dry_run="${3:-false}"
    local mode="${4:-}"

    if [[ "$dry_run" == "true" ]]; then
        info "[dry-run] 将写入文件: $target_file"
        print_code "$content"
        return 0
    fi

    ensure_parent_dir "$target_file"
    printf '%s\n' "$content" > "$target_file"

    if [[ -n "$mode" ]]; then
        chmod "$mode" "$target_file"
    fi
}
