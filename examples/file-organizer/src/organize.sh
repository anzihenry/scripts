#!/bin/zsh
# filepath: src/organize.sh
organizer_apply() {
    local directory="$1" dry_run="$2" file category suffix target parent moved=0
    local -a sources=() targets=()
    # Scan only ordinary top-level files. Links and directories are never moved.
    for file in "$directory"/*(N.); do
        [[ ! -L "$file" ]] || continue
        suffix="${(L)file:e}"
        case "$suffix" in
            txt|md|pdf) category=documents ;;
            png|jpg|jpeg) category=images ;;
            *) category=other ;;
        esac
        target="$directory/organized/$category/${file:t}"
        for parent in "$directory/organized" "$directory/organized/$category"; do
            [[ ! -L "$parent" && ( ! -e "$parent" || -d "$parent" ) ]] || { sk_error "目标目录无效: $parent"; return 1; }
        done
        [[ ! -e "$target" && ! -L "$target" ]] || { sk_error "目标已存在，未开始移动: $target"; return 1; }
        sources+=("$file"); targets+=("$target")
    done
    local index
    for ((index=1; index<=${#sources}; index++)); do
        file="${sources[index]}"; target="${targets[index]}"
        if [[ "$dry_run" == true ]]; then
            sk_command_preview mv -n "$file" "$target"; printf '\n'
            continue
        fi
        mkdir -p "${target:h}" || return 1
        # -n prevents overwrite if an uncooperative writer creates the target after planning.
        if ! mv -n "$file" "$target" || [[ -e "$file" || -L "$file" ]]; then
            sk_error "移动失败: $file；已完成 $moved 个文件。修复后重跑，已移动文件不会重复处理。"
            return 1
        fi
        moved=$((moved + 1))
        sk_info "已移动: ${file:t} → ${target:h:t}"
    done
    sk_success "扫描 ${#sources} 个文件；已移动 $moved 个；dry-run=$dry_run"
}
organizer_main() {
    (( $# >= 1 && $# <= 2 )) || { print -u2 '用法: file-organizer organize DIRECTORY [--dry-run]'; return 2; }
    local directory="${1:A}" dry_run=false
    if (( $# == 2 )); then [[ "$2" == --dry-run ]] || return 2; dry_run=true; fi
    [[ -d "$directory" ]] || { print -u2 '目录不存在'; return 2; }
    source "$APP_ROOT/vendor/zsh-kit/lib/zsh-kit.sh" || return 1
    local version
    command -v sw_vers >/dev/null || return 1
    version="$(sw_vers -productVersion)" || return 1
    [[ "${version%%.*}" == <-> ]] && (( ${version%%.*} >= APP_MIN_MACOS )) || return 1
    if [[ "$dry_run" == true ]]; then organizer_apply "$directory" true; return $?; fi
    local log_key="${APP_ENV_PREFIX}_LOG_DIR" log_dir
    log_dir="${(P)log_key:-$APP_DEFAULT_LOG_DIR}"
    # Logs must stay outside the directory being scanned.
    [[ "${log_dir:A}/" != "$directory/"* ]] || { sk_error '日志目录不能位于待整理目录内'; return 2; }
    mkdir -p "$log_dir" || return 1
    sk_start_capture "$log_dir/run.log" separate || return 1
    sk_run_timed_command_or_fail organize '开始整理' '整理完成' '整理失败' '查看日志，解决冲突或权限问题后重试。' \
        sk_with_resource_lock "$directory/.file-organizer-resource" organizer_apply "$directory" false
}
