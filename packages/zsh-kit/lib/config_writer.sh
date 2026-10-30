#!/bin/zsh
# filepath: packages/zsh-kit/lib/config_writer.sh

source "${${(%):-%x}:A:h}/resource_lock.sh"

_sk_ensure_parent_dir() {
    mkdir -p "${1:h}"
}

# 同目录替换，保留现有权限和符号链接；相同内容不触碰目标文件。
_sk_commit_config_candidate() {
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

sk_write_managed_block() (
    (( $# >= 4 && $# <= 7 )) || return 2
    _sk_required "$1" || return 2
    _sk_line "$2" && _sk_line "$3" && _sk_line "${6-managed by}" || return 2
    _sk_bool "${5-false}" && _sk_bool "${7-false}" || return 2
    _sk_uint "${SK_LOCK_TIMEOUT-10}" 0 9999 || return 2
    local target_file="$1" section_name="$2" manager_name="$3" content="$4"
    local dry_run="${5:-false}" marker_style="${6:-managed by}"
    local validate_shell="${7:-false}"
    local start_marker="# >>> ${section_name} (${marker_style} ${manager_name}) >>>"
    local end_marker="# <<< ${section_name} (${marker_style} ${manager_name}) <<<"
    if [[ "$dry_run" == true ]]; then
        sk_info "[dry-run] 将更新 $target_file 中的 ${section_name} 配置块"
        printf '%s\n' "$start_marker" "$content" "$end_marker"
        return 0
    fi
    [[ ! -L "$target_file" || -e "$target_file" ]] || { sk_error "配置为失效符号链接: $target_file"; return 1; }
    target_file="${target_file:A}"
    [[ ! -e "$target_file" || -f "$target_file" ]] || { sk_error "配置不是普通文件: $target_file"; return 1; }
    sk_resource_lock_acquire "$target_file" || return 1
    _sk_ensure_parent_dir "$target_file" || return 1
    local candidate replacement input="/dev/null"
    candidate="$(mktemp "${target_file}.write.XXXXXXXX")" || return 1
    replacement="$(mktemp "${target_file}.block.XXXXXXXX")" || { rm -f "$candidate"; return 1; }
    trap 'rm -f "$candidate" "$replacement"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM HUP
    printf '%s\n' "$start_marker" "$content" "$end_marker" > "$replacement" || return 1
    [[ ! -f "$target_file" ]] || input="$target_file"
    if ! SK_AWK_START="$start_marker" SK_AWK_END="$end_marker" SK_AWK_BLOCK="$replacement" awk '
      BEGIN { start=ENVIRON["SK_AWK_START"]; end=ENVIRON["SK_AWK_END"]; block=ENVIRON["SK_AWK_BLOCK"] }
      function emit( line) { while ((getline line < block) > 0) print line; close(block) }
      $0 == start { if (seen++ || active) { bad=1; exit 1 }; active=1; emit(); next }
      $0 == end { if (!active) { bad=1; exit 1 }; active=0; next }
      active && /^# (>>>|<<<) / { bad=1; exit 1 }
      !active { print; last=$0 }
      END { if (bad || active) exit 1; if (!seen) { if (NR && last != "") print ""; emit() } }
    ' "$input" > "$candidate"; then
        sk_error "配置块缺失、重复或交错，未修改文件: $target_file"
        return 1
    fi
    if [[ "$validate_shell" == true ]]; then
        /bin/zsh -n "$candidate" || { sk_error "Shell 配置语法无效，原文件未修改: $target_file"; return 1; }
    fi
    _sk_commit_config_candidate "$target_file" "$candidate"
)

sk_write_managed_file() (
    (( $# >= 2 && $# <= 4 )) || return 2
    _sk_required "$1" || return 2
    _sk_bool "${3-false}" && _sk_mode "${4-}" || return 2
    _sk_uint "${SK_LOCK_TIMEOUT-10}" 0 9999 || return 2
    local target_file="$1" content="$2" dry_run="${3:-false}" mode="${4:-}"
    if [[ "$dry_run" == true ]]; then
        sk_info "[dry-run] 将写入文件: $target_file"
        _sk_print_code "$content"
        return 0
    fi
    [[ ! -L "$target_file" || -e "$target_file" ]] || { sk_error "配置为失效符号链接: $target_file"; return 1; }
    target_file="${target_file:A}"
    [[ ! -e "$target_file" || -f "$target_file" ]] || return 1
    sk_resource_lock_acquire "$target_file" || return 1
    _sk_ensure_parent_dir "$target_file" || return 1
    local candidate
    candidate="$(mktemp "${target_file}.write.XXXXXXXX")" || return 1
    trap 'rm -f "$candidate"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    trap 'exit 129' HUP
    printf '%s\n' "$content" > "$candidate" || { rm -f "$candidate"; return 1; }
    _sk_commit_config_candidate "$target_file" "$candidate" "$mode"
)



# 仅更新指定 INI 键，保留其他节、注释及用户选项。
_sk_update_ini_candidate() (
    local target="$1" section="$2" key="$3" value="$4" candidate input=/dev/null
    [[ ! -L "$target" || -e "$target" ]] || return 1
    target="${target:A}"
    [[ ! -e "$target" || -f "$target" ]] || return 1
    _sk_ensure_parent_dir "$target" || return 1
    candidate="$(mktemp "${target}.ini.XXXXXXXX")" || return 1
    trap 'rm -f "$candidate"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    trap 'exit 129' HUP
    [[ ! -f "$target" ]] || input="$target"
    SK_AWK_SECTION="[$section]" SK_AWK_KEY="$key" SK_AWK_VALUE="$value" awk '
      BEGIN { wanted=ENVIRON["SK_AWK_SECTION"]; key=ENVIRON["SK_AWK_KEY"]; value=ENVIRON["SK_AWK_VALUE"] }
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
    _sk_commit_config_candidate "$target" "$candidate"
)

# 多键更新在同一个候选文件上完成，仅一次提交；中途失败原文件保持不变。
sk_set_ini_values() (
    (( $# >= 4 && $# % 2 == 0 )) || return 2
    _sk_required "$1" && _sk_line "$2" || return 2
    [[ "$2" != *'['* && "$2" != *']'* ]] || return 2
    _sk_uint "${SK_LOCK_TIMEOUT-10}" 0 9999 || return 2
    local index
    for ((index=3; index<=$#; index+=2)); do
        _sk_line "${@[index]}" || return 2
        [[ "${@[index]}" != *'='* && "${@[index]}" != [\#\;\[]* ]] || return 2
        [[ "${@[index+1]}" != *$'\n'* && "${@[index+1]}" != *$'\r'* ]] || return 2
    done
    local target="$1" section="$2" candidate
    shift 2
    (( $# > 0 && $# % 2 == 0 )) || return 2
    [[ ! -L "$target" || -e "$target" ]] || return 1
    target="${target:A}"
    [[ ! -e "$target" || -f "$target" ]] || return 1
    sk_resource_lock_acquire "$target" || return 1
    _sk_ensure_parent_dir "$target" || return 1
    candidate="$(mktemp "${target}.ini-batch.XXXXXXXX")" || return 1
    trap 'rm -f "$candidate"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    trap 'exit 129' HUP
    [[ ! -f "$target" ]] || cp -p "$target" "$candidate" || return 1
    while (( $# > 0 )); do
        _sk_update_ini_candidate "$candidate" "$section" "$1" "$2" || return 1
        shift 2
    done
    _sk_commit_config_candidate "$target" "$candidate"
)

sk_set_ini_value() {
    (( $# == 4 )) || return 2
    sk_set_ini_values "$1" "$2" "$3" "$4"
}

# Advanced API: prepare/validate candidate under the target resource lock.
# This function also locks the commit, but cannot repair a candidate prepared from stale data.
sk_commit_config_candidate() (
    (( $# >= 2 && $# <= 3 )) || return 2
    _sk_required "$1" && _sk_required "$2" && _sk_mode "${3-}" || return 2
    _sk_uint "${SK_LOCK_TIMEOUT-10}" 0 9999 || return 2
    [[ ! -L "$2" && -f "$2" && ( ! -L "$1" || -e "$1" ) ]] || return 2
    local target="${1:A}" candidate="${2:A}"
    [[ "$target" != "$candidate" && "${target:h}" == "${candidate:h}" ]] || return 2
    [[ ! -e "$target" || -f "$target" ]] || return 1
    sk_resource_lock_acquire "$target" || return $?
    _sk_commit_config_candidate "$target" "$candidate" "${3-}"
)
