#!/bin/zsh
# filepath: setup/lib/homebrew_config.sh

# shellcheck disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/../../lib/utils.sh"
source "${${(%):-%x}:A:h}/homebrew_transaction.sh"

homebrew_config_run() {
    local dry_run="${1:-false}"
    local description="$2"
    shift 2

    if [[ "$dry_run" == "true" ]]; then
        info "[dry-run] $description"
        print_code "$*"
        return 0
    fi

    info "$description"
    "$@"
}

# resolve_homebrew_bin 由 lib/utils.sh 统一提供（本文件已 source utils.sh）

activate_homebrew_environment() {
    local brew_bin="$1"
    local brew_prefix
    brew_prefix="$($brew_bin --prefix)" || return 1

    export PATH="${brew_prefix}/bin:${brew_prefix}/sbin:$PATH"
    local shellenv_content
    shellenv_content="$($brew_bin shellenv)" || return 1
    eval "$shellenv_content"
}

update_managed_zsh_config() {
    local section_name="$1"
    local manager_name="$2"
    local config_content="$3"
    local dry_run="${4:-false}"
    local rc_file="$HOME/.zshrc"
    rc_file="${rc_file:A}"
    write_managed_block "$rc_file" "$section_name" "$manager_name" "$config_content" "$dry_run"
}

get_homebrew_mirror_config() {
    cat <<'EOF'
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.ustc.edu.cn/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.ustc.edu.cn/homebrew-core.git"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"
export HOMEBREW_API_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles/api"
EOF
}

configure_homebrew_shellenv() {
    local brew_bin="$1"
    local dry_run="${2:-false}"
    local brew_prefix
    local shellenv_content

    brew_prefix="$($brew_bin --prefix)" || return 1
    shellenv_content=$(cat <<EOF
export PATH="${brew_prefix}/bin:${brew_prefix}/sbin:\$PATH"
eval "\$(${brew_prefix}/bin/brew shellenv)"
EOF
)

    update_managed_zsh_config "Homebrew Basic" "homebrew-config" "$shellenv_content" "$dry_run" || return 1
    if [[ "$dry_run" == "true" ]]; then
        success "已预演 Homebrew shellenv 配置更新"
    else
        success "已更新 ~/.zshrc 中的 Homebrew shellenv 配置"
    fi
}

configure_homebrew_mirror_exports() {
    local dry_run="${1:-false}"
    local mirror_config

    mirror_config="$(get_homebrew_mirror_config)"
    update_managed_zsh_config "Homebrew Mirror" "homebrew-config" "$mirror_config" "$dry_run" || return 1
    eval "$mirror_config"
    if [[ "$dry_run" == "true" ]]; then
        success "已预演 Homebrew 镜像配置更新"
    else
        success "已更新 ~/.zshrc 中的 Homebrew 镜像配置"
    fi
}

verify_homebrew_mirror_remote() {
    local repo_path="$1"
    local dry_run="$2"
    local index
    if [[ "$dry_run" == true ]]; then
        homebrew_config_run true "验证 USTC 镜像连通性（不重置仓库）" git -C "$repo_path" ls-remote --exit-code origin HEAD
        return 0
    fi
    for ((index = 1; index <= 3; index++)); do
        if git -C "$repo_path" ls-remote --exit-code origin HEAD > /dev/null; then
            return 0
        fi
        if (( index < 3 )); then
            warning "镜像验证第 ${index} 次失败，10 秒后重试..."
            sleep 10 || return 1
        fi
    done
    error "USTC 镜像验证失败。请检查网络后重新执行 setup brew configure。"
    return 1
}

sync_homebrew_mirror_remotes() {
    local brew_bin="$1"
    local dry_run="${2:-false}"
    local brew_repo core_repo_path
    brew_repo="$($brew_bin --repo)" || return 1
    [[ -n "$brew_repo" ]] || { error "无法获取 Homebrew 仓库路径"; return 1; }
    core_repo_path="$brew_repo/Library/Taps/homebrew/homebrew-core"

    homebrew_config_run "$dry_run" "切换 Homebrew brew 仓库远程地址" git -C "$brew_repo" remote set-url origin "$HOMEBREW_BREW_GIT_REMOTE" || return 1
    verify_homebrew_mirror_remote "$brew_repo" "$dry_run" || return 1
    if [[ -d "$core_repo_path" ]]; then
        homebrew_config_run "$dry_run" "切换 homebrew-core 仓库远程地址" git -C "$core_repo_path" remote set-url origin "$HOMEBREW_CORE_GIT_REMOTE" || return 1
        verify_homebrew_mirror_remote "$core_repo_path" "$dry_run" || return 1
    else
        info "未检测到本地 homebrew-core tap，保留 API 镜像配置，不额外克隆仓库。"
    fi
    success "Homebrew 镜像配置验证完成（未更新或重置仓库内容）"
}

configure_homebrew_environment() {
    local brew_bin="$1"
    local dry_run="${2:-false}"
    activate_homebrew_environment "$brew_bin" || return 1
    if [[ "$dry_run" == true ]]; then
        (
            configure_homebrew_shellenv "$brew_bin" true &&
            configure_homebrew_mirror_exports true &&
            sync_homebrew_mirror_remotes "$brew_bin" true
        )
        return $?
    fi
    run_homebrew_config_transaction "$brew_bin" || return 1
    # 仅在事务成功后将镜像环境应用到调用方（供 setup packages 后续步骤使用）。
    local mirror_config
    mirror_config="$(get_homebrew_mirror_config)" || return 1
    eval "$mirror_config"
}
