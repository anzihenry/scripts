#!/bin/zsh
# filepath: setup/lib/homebrew_config.sh

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

resolve_homebrew_bin() {
    if command -v brew >/dev/null 2>&1; then
        command -v brew
        return 0
    fi

    if [[ -x /opt/homebrew/bin/brew ]]; then
        printf '%s' "/opt/homebrew/bin/brew"
        return 0
    fi

    if [[ -x /usr/local/bin/brew ]]; then
        printf '%s' "/usr/local/bin/brew"
        return 0
    fi

    return 1
}

activate_homebrew_environment() {
    local brew_bin="$1"
    local brew_prefix
    brew_prefix="$($brew_bin --prefix)"

    export PATH="${brew_prefix}/bin:${brew_prefix}/sbin:$PATH"
    eval "$($brew_bin shellenv)"
}

update_managed_zsh_config() {
    local section_name="$1"
    local manager_name="$2"
    local config_content="$3"
    local dry_run="${4:-false}"
    local rc_file="$HOME/.zshrc"
    local start_marker="# >>> ${section_name} (managed by ${manager_name}) >>>"
    local end_marker="# <<< ${section_name} (managed by ${manager_name}) <<<"

    if [[ "$dry_run" == "true" ]]; then
        info "[dry-run] 将更新 $rc_file 中的 ${section_name} 配置块"
        print_code "$start_marker"
        printf '%s\n' "$config_content"
        print_code "$end_marker"
        return 0
    fi

    touch "$rc_file"

    if grep -Fq "$start_marker" "$rc_file"; then
        sed -i '' "\\|$start_marker|,\\|$end_marker|d" "$rc_file"
    fi

    {
        echo ""
        echo "$start_marker"
        echo "$config_content"
        echo "$end_marker"
    } >> "$rc_file"
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

    brew_prefix="$($brew_bin --prefix)"
    shellenv_content=$(cat <<EOF
export PATH="${brew_prefix}/bin:${brew_prefix}/sbin:\$PATH"
eval "\$(${brew_prefix}/bin/brew shellenv)"
EOF
)

    update_managed_zsh_config "Homebrew Basic" "homebrew-config" "$shellenv_content" "$dry_run"
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
    update_managed_zsh_config "Homebrew Mirror" "homebrew-config" "$mirror_config" "$dry_run"
    eval "$mirror_config"
    if [[ "$dry_run" == "true" ]]; then
        success "已预演 Homebrew 镜像配置更新"
    else
        success "已更新 ~/.zshrc 中的 Homebrew 镜像配置"
    fi
}

sync_homebrew_mirror_remotes() {
    local brew_bin="$1"
    local dry_run="${2:-false}"
    local retry_count=3
    local brew_repo
    local core_repo_path
    local index

    brew_repo="$($brew_bin --repo)"
    homebrew_config_run "$dry_run" "切换 Homebrew brew 仓库远程地址" git -C "$brew_repo" remote set-url origin "$HOMEBREW_BREW_GIT_REMOTE"

    core_repo_path="$brew_repo/Library/Taps/homebrew/homebrew-core"
    if [[ ! -d "$core_repo_path" ]]; then
        if [[ "$dry_run" == "true" ]]; then
            info "[dry-run] 将初始化 homebrew-core 仓库"
            print_code "mkdir -p \"$(dirname "$core_repo_path")\""
            print_code "git clone \"$HOMEBREW_CORE_GIT_REMOTE\" \"$core_repo_path\""
        else
            warning "初始化 homebrew-core 仓库..."
            mkdir -p "$(dirname "$core_repo_path")"
            git clone "$HOMEBREW_CORE_GIT_REMOTE" "$core_repo_path"
        fi
    fi
    homebrew_config_run "$dry_run" "切换 homebrew-core 仓库远程地址" git -C "$core_repo_path" remote set-url origin "$HOMEBREW_CORE_GIT_REMOTE"

    if [[ "$dry_run" == "true" ]]; then
        info "[dry-run] 将同步 Homebrew 镜像配置"
        print_code "$brew_bin update-reset -q"
        success "已预演 Homebrew 镜像同步"
        return 0
    fi

    warning "正在同步 Homebrew 镜像配置 (带重试)..."
    for ((index = 1; index <= retry_count; index++)); do
        if $brew_bin update-reset -q; then
            success "Homebrew 镜像同步完成"
            return 0
        fi

        if [[ $index -lt $retry_count ]]; then
            warning "第 ${index} 次同步失败，10 秒后重试..."
            sleep 10
        fi
    done

    log_fatal "Homebrew 镜像同步失败，已达最大重试次数"
}

configure_homebrew_environment() {
    local brew_bin="$1"
    local dry_run="${2:-false}"

    activate_homebrew_environment "$brew_bin"
    configure_homebrew_shellenv "$brew_bin" "$dry_run"
    configure_homebrew_mirror_exports "$dry_run"
    sync_homebrew_mirror_remotes "$brew_bin" "$dry_run"
}