#!/bin/zsh
# filepath: setup/lib/homebrew_transaction.sh
# Homebrew 配置事务：备份实际文件，子进程内写入，失败/中断时恢复。

homebrew_snapshot_file() {
    local target_file="$1"
    local index=$((${#HBC_TARGETS[@]} + 1))
    # 跟随现有符号链接备份目标，配置写入与恢复也使用该目标。
    if [[ -L "$target_file" && ! -e "$target_file" ]]; then
        error "配置路径为失效符号链接，请先修复: $target_file"
        return 1
    fi
    target_file="${target_file:A}"
    if [[ -e "$target_file" && ! -f "$target_file" ]]; then
        error "配置目标不是普通文件: $target_file"
        return 1
    fi
    if [[ -f "$target_file" ]]; then
        cp -p "$target_file" "$HBC_BACKUP_DIR/$index" || {
            error "无法备份配置，尚未修改文件，请检查读写权限: $target_file"
            return 1
        }
        HBC_EXISTED+=(1)
    else
        HBC_EXISTED+=(0)
    fi
    HBC_TARGETS+=("$target_file")
    printf '%s\t%s\t%s\n' "$index" "${HBC_EXISTED[index]}" "$target_file" >> "$HBC_BACKUP_DIR/manifest.tsv"
}

homebrew_snapshot_git_config() {
    local repo_path="$1"
    local config_path
    config_path="$(git -C "$repo_path" rev-parse --git-path config)" || {
        error "无法定位 Git 配置，请检查仓库状态: $repo_path"
        return 1
    }
    [[ -n "$config_path" ]] || return 1
    [[ "$config_path" == /* ]] || config_path="$repo_path/$config_path"
    [[ ! -L "$config_path" ]] || { error "Git 配置为符号链接，请先确认其写入方式: $config_path"; return 1; }
    [[ -f "$config_path" ]] || { error "找不到 Git 配置: $config_path"; return 1; }
    homebrew_snapshot_file "$config_path"
}

homebrew_restore_snapshot() {
    local index target_file restore_file
    local failed=0
    for ((index = ${#HBC_TARGETS[@]}; index >= 1; index--)); do
        target_file="${HBC_TARGETS[index]}"
        if [[ "${HBC_EXISTED[index]}" == 1 ]]; then
            restore_file="$(mktemp "${target_file}.restore.XXXXXXXX")" || { failed=1; continue; }
            if ! cp -p "$HBC_BACKUP_DIR/$index" "$restore_file" || ! mv -f "$restore_file" "$target_file"; then
                rm -f "$restore_file"
                error "恢复失败，请从备份手动还原: $target_file"
                failed=1
            fi
        else
            rm -f "$target_file" || failed=1
        fi
    done
    return "$failed"
}

homebrew_transaction_cleanup() {
    local exit_code=$?
    trap - EXIT INT TERM HUP
    if [[ "$HBC_COMMITTED" != true && "$HBC_STARTED" == true ]]; then
        if homebrew_restore_snapshot; then
            warning "Homebrew 配置失败，已恢复本次修改；已安装的 Homebrew 和 CLI 保留。"
        else
            error "Homebrew 配置失败，部分文件未能自动恢复。备份: $HBC_BACKUP_DIR"
        fi
    elif [[ "$HBC_COMMITTED" == true ]]; then
        if rm -rf "$HBC_BACKUP_DIR"; then
            info "已删除本次成功配置的备份。"
        else
            warning "配置已成功，但备份清理失败，可手动删除: $HBC_BACKUP_DIR"
        fi
    fi
    return "$exit_code"
}

validate_homebrew_managed_blocks() {
    local rc_file="$HOME/.zshrc"
    [[ -e "$rc_file" ]] || return 0
    # 拒绝缺失、重复或交错的标记，避免范围删除吞掉用户配置。
    awk '
      index($0, "# >>> Homebrew Basic (managed by homebrew-config) >>>") { if (active || basic++) exit 1; active="basic"; next }
      index($0, "# >>> Homebrew Mirror (managed by homebrew-config) >>>") { if (active || mirror++) exit 1; active="mirror"; next }
      index($0, "# <<< Homebrew Basic (managed by homebrew-config) <<<") { if (active != "basic") exit 1; active=""; next }
      index($0, "# <<< Homebrew Mirror (managed by homebrew-config) <<<") { if (active != "mirror") exit 1; active=""; next }
      END { if (active) exit 1 }
    ' "$rc_file" || { error "Homebrew 配置块标记不完整或重复，未修改文件，请先修复: $rc_file"; return 1; }
}

run_homebrew_config_transaction() (
    # 子进程隔离 trap 和镜像环境变量；每个修改步骤显式传播错误。
    local brew_bin="$1"
    local backup_root="${MACOS_SCRIPTS_CONFIG_DIR:-$HOME/.config/macos-scripts}/backups"
    local HBC_LOCK_DIR="$backup_root/.homebrew-config.lock"
    local HBC_BACKUP_DIR=""
    local HBC_COMMITTED=false HBC_STARTED=false
    local -a HBC_TARGETS=() HBC_EXISTED=()
    local brew_repo core_repo

    homebrew_resource_lock "$brew_bin" || return 1
    resource_lock_acquire "$HOME/.zshrc" || return 1
    mkdir -p "$backup_root" || return 1
    if [[ -e "$HBC_LOCK_DIR" ]]; then
        error "另一个 Homebrew 配置可能正在运行。确认其已结束后，可清理锁目录再重试: $HBC_LOCK_DIR"
        return 1
    fi
    trap homebrew_transaction_cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    trap 'exit 129' HUP
    validate_homebrew_managed_blocks || return 1
    if homebrew_configuration_current "$brew_bin"; then
        success "Homebrew 配置已符合目标状态，跳过备份和写入。"
        return 0
    fi
    HBC_BACKUP_DIR="$(umask 077; mktemp -d "$backup_root/homebrew-config.XXXXXXXX")" || return 1
    info "Homebrew 配置备份: $HBC_BACKUP_DIR"

    validate_homebrew_managed_blocks || return 1
    brew_repo="$($brew_bin --repo)" || return 1
    [[ -d "$brew_repo" ]] || { error "Homebrew 仓库目录无效: $brew_repo"; return 1; }
    core_repo="$brew_repo/Library/Taps/homebrew/homebrew-core"
    homebrew_snapshot_file "$HOME/.zshrc" || return 1
    homebrew_snapshot_git_config "$brew_repo" || return 1
    if [[ -d "$core_repo" ]]; then
        homebrew_snapshot_git_config "$core_repo" || return 1
    fi

    HBC_STARTED=true
    configure_homebrew_shellenv "$brew_bin" false || return 1
    configure_homebrew_mirror_exports false || return 1
    /bin/zsh -n "$HOME/.zshrc" || { error ".zshrc 语法校验失败，恢复原配置。"; return 1; }
    sync_homebrew_mirror_remotes "$brew_bin" false || return 1
    HBC_COMMITTED=true
    success "Homebrew 配置已完成。"
)
