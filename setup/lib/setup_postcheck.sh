#!/bin/zsh
# filepath: setup/lib/setup_postcheck.sh

post_verification() {
    print_header "安装后验证"
    local module section managed value
    local has_warning=false
    local -a critical_cmds=(git brew)
    for module in node python ruby go android; do
        setup_module_enabled "$module" || continue
        case "$module" in
            node) section=NVM; critical_cmds+=(node npm) ;;
            python) section='Python Env'; critical_cmds+=(python pip python3 pip3) ;;
            ruby) section='Ruby Env'; critical_cmds+=(ruby gem) ;;
            go) section='Go Env'; critical_cmds+=(go) ;;
            android) section='Android & Java Env' ;;
        esac
        managed="$(awk -v begin="# >>> $section (managed by macos-setup) >>>" -v end="# <<< $section (managed by macos-setup) <<<" '$0==begin {active=1;next} $0==end {active=0;next} active {print}' "$HOME/.zshrc")" || return 1
        [[ -n "$managed" ]] || { error "缺少配置块: $section"; return 1; }
        eval "$managed" || return 1
    done
    local cmd
    for cmd in "${critical_cmds[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            warning "命令缺失: $cmd"
            has_warning=true
        fi
    done
    if setup_module_enabled go; then
        if ! value="$(go env GOPROXY)" || [[ "$value" != "$SETUP_GOPROXY" ]]; then warning "GOPROXY 未正确配置"; has_warning=true; fi
    fi
    if setup_module_enabled node; then
        if ! value="$(npm config get registry)" || [[ "${value%/}" != "${SETUP_NPM_REGISTRY%/}" ]]; then warning "NPM 镜像源未配置"; has_warning=true; fi
    fi
    if setup_module_enabled ruby; then
        if ! value="$(gem sources -l)" || ! printf '%s\n' "$value" | grep -Fxq -- "$SETUP_GEM_SOURCE"; then warning "Ruby 镜像源未配置"; has_warning=true; fi
    fi
    if setup_module_enabled python; then
        if ! value="$(pip config get global.index-url)" || [[ "$value" != "$SETUP_PIP_INDEX" ]]; then warning "pip 镜像源未配置"; has_warning=true; fi
    fi
    if [[ "$has_warning" == false ]]; then success "基础环境验证通过"; else error "部分环境验证失败，请检查日志"; return 1; fi
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
