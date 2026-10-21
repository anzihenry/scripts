#!/bin/zsh
# filepath: setup/lib/config_writer.sh

ensure_parent_dir() {
    mkdir -p "${1:h}"
}

# 同目录替换，保留现有权限和符号链接；相同内容不触碰目标文件。
commit_config_candidate() {
    local target="$1" candidate="$2" mode="${3:-}"
    if [[ -f "$target" ]] && cmp -s "$target" "$candidate"; then
        rm -f "$candidate"
        if [[ -n "$mode" && "$(stat -f '%Lp' "$target")" != "$mode" ]]; then
            chmod "$mode" "$target" || return 1
        fi
        return 0
    fi
    if [[ -f "$target" ]]; then
        local permissions
        permissions="$(stat -f '%Lp' "$target")" || { rm -f "$candidate"; return 1; }
        chmod "$permissions" "$candidate" || { rm -f "$candidate"; return 1; }
    fi
    [[ -z "$mode" ]] || chmod "$mode" "$candidate" || { rm -f "$candidate"; return 1; }
    mv -f "$candidate" "$target" || { rm -f "$candidate"; return 1; }
}

write_managed_block() (
    local target_file="$1" section_name="$2" manager_name="$3" content="$4"
    local dry_run="${5:-false}" marker_style="${6:-managed by}"
    local validate_shell=false
    [[ "${target_file:t}" != .zshrc ]] || validate_shell=true
    local start_marker="# >>> ${section_name} (${marker_style} ${manager_name}) >>>"
    local end_marker="# <<< ${section_name} (${marker_style} ${manager_name}) <<<"
    if [[ "$dry_run" == true ]]; then
        info "[dry-run] 将更新 $target_file 中的 ${section_name} 配置块"
        printf '%s\n' "$start_marker" "$content" "$end_marker"
        return 0
    fi
    [[ ! -L "$target_file" || -e "$target_file" ]] || { error "配置为失效符号链接: $target_file"; return 1; }
    target_file="${target_file:A}"
    [[ ! -e "$target_file" || -f "$target_file" ]] || { error "配置不是普通文件: $target_file"; return 1; }
    ensure_parent_dir "$target_file" || return 1
    local candidate replacement input="/dev/null"
    candidate="$(mktemp "${target_file}.write.XXXXXXXX")" || return 1
    replacement="$(mktemp "${target_file}.block.XXXXXXXX")" || { rm -f "$candidate"; return 1; }
    trap 'rm -f "$candidate" "$replacement"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM HUP
    printf '%s\n' "$start_marker" "$content" "$end_marker" > "$replacement" || return 1
    [[ ! -f "$target_file" ]] || input="$target_file"
    if ! awk -v start="$start_marker" -v end="$end_marker" -v block="$replacement" '
      function emit( line) { while ((getline line < block) > 0) print line; close(block) }
      $0 == start { if (seen++ || active) { bad=1; exit 1 }; active=1; emit(); next }
      $0 == end { if (!active) { bad=1; exit 1 }; active=0; next }
      active && /^# (>>>|<<<) / { bad=1; exit 1 }
      !active { print; last=$0 }
      END { if (bad || active) exit 1; if (!seen) { if (NR && last != "") print ""; emit() } }
    ' "$input" > "$candidate"; then
        error "配置块缺失、重复或交错，未修改文件: $target_file"
        return 1
    fi
    if [[ "$validate_shell" == true ]]; then
        /bin/zsh -n "$candidate" || { error "Shell 配置语法无效，原文件未修改: $target_file"; return 1; }
    fi
    commit_config_candidate "$target_file" "$candidate"
)

write_managed_file() {
    local target_file="$1" content="$2" dry_run="${3:-false}" mode="${4:-}"
    if [[ "$dry_run" == true ]]; then
        info "[dry-run] 将写入文件: $target_file"
        print_code "$content"
        return 0
    fi
    [[ ! -L "$target_file" || -e "$target_file" ]] || { error "配置为失效符号链接: $target_file"; return 1; }
    target_file="${target_file:A}"
    [[ ! -e "$target_file" || -f "$target_file" ]] || return 1
    ensure_parent_dir "$target_file" || return 1
    local candidate
    candidate="$(mktemp "${target_file}.write.XXXXXXXX")" || return 1
    printf '%s\n' "$content" > "$candidate" || { rm -f "$candidate"; return 1; }
    commit_config_candidate "$target_file" "$candidate" "$mode"
}

update_shell_config() {
    write_managed_block "$HOME/.zshrc" "$1" macos-setup "$2" || return 1
    success "$1 环境配置已就绪"
}

# 仅更新指定 INI 键，保留其他节、注释及用户选项。
set_ini_value() (
    local target="$1" section="$2" key="$3" value="$4" candidate input=/dev/null
    [[ ! -L "$target" || -e "$target" ]] || return 1
    target="${target:A}"
    [[ ! -e "$target" || -f "$target" ]] || return 1
    ensure_parent_dir "$target" || return 1
    candidate="$(mktemp "${target}.ini.XXXXXXXX")" || return 1
    trap 'rm -f "$candidate"' EXIT
    [[ ! -f "$target" ]] || input="$target"
    awk -v wanted="[$section]" -v key="$key" -v value="$value" '
      /^[[:space:]]*\[/ {
        if (active && !written) { print key " = " value; written=1 }
        header=$0; gsub(/^[[:space:]]+|[[:space:]]+$/, "", header)
        active=(header==wanted)
        if (active && seen++) {bad=1; exit 1}
      }
      active && /^[[:space:]]*[^#;][^=]*=/ {
        name=$0; sub(/=.*/, "", name); gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
        if (tolower(name)==tolower(key)) {if (!written) print key " = " value; written=1; next}
      }
      { print }
      END { if (bad) exit 1; if (!seen) print wanted; if (!written) print key " = " value }
    ' "$input" > "$candidate" || return 1
    commit_config_candidate "$target" "$candidate"
)
