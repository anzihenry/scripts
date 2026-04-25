#!/bin/zsh
# filepath: setup/lib/setup_postcheck.sh

post_verification() {
    print_header "安装后验证"
    source ~/.zshrc

    local has_warning=false
    local critical_cmds=(git brew node npm ruby go python pip python3 pip3)
    local cmd

    for cmd in "${critical_cmds[@]}"; do
        if ! command -v $cmd &>/dev/null; then
            warning "命令缺失: $cmd"
            has_warning=true
        fi
    done

    [[ -z "$(go env GOPROXY)" ]] && warning "GOPROXY 未正确配置" && has_warning=true
    [[ "$(npm config get registry)" != "https://registry.npmmirror.com/" ]] && warning "NPM 镜像源未配置" && has_warning=true
    [[ -z "$(gem sources -l | grep ustc)" ]] && warning "Ruby 镜像源未配置" && has_warning=true
    [[ "$(pip config get global.index-url)" != "https://mirrors.ustc.edu.cn/pypi/simple" ]] && warning "pip 镜像源未配置" && has_warning=true

    if [[ "$has_warning" == "false" ]]; then
        success "基础环境验证通过"
    else
        error "部分环境验证失败，请检查日志"
    fi
}

print_setup_completion() {
    print_header "🎉 配置完成!"
    info "建议后续操作:"
    info "1. ${BOLD}完全重启终端${NC} 或执行 $(highlight 'source ~/.zshrc') 来刷新环境。"
    info "2. 检查新的配置文件位置："
    info "   - $(highlight "$BREW_CONFIG_FILE")"
    info "3. 日志文件位置："
    info "   - $(highlight "$SETUP_LOG_FILE")"
}
