#!/bin/zsh
# filepath: setup/lib/setup_runtime.sh

initialize_setup_context() {
    SETUP_LOG_FILE="$(prepare_log_file_path "macos-setup.log" "$SCRIPT_DIR/setup.log")"
    enable_log_capture "$SETUP_LOG_FILE"

    DEFAULT_BREW_CONFIG_FILE="${SCRIPT_DIR}/brew.conf.sh"

    if [[ -n "${MACOS_SCRIPTS_CONFIG_DIR:-}" ]]; then
        mkdir -p "$MACOS_SCRIPTS_CONFIG_DIR"
        BREW_CONFIG_FILE="${MACOS_SCRIPTS_CONFIG_DIR}/brew.conf.sh"
    else
        BREW_CONFIG_FILE="$DEFAULT_BREW_CONFIG_FILE"
    fi
}

collect_configured_package_values() {
    local prefix="$1"
    local -a matched_names=()
    local name
    for name in ${(k)parameters}; do
        [[ "$name" == ${prefix}* ]] || continue
        [[ "${(Pt)name}" == *array* ]] || continue
        matched_names+=("$name")
    done

    local -a values=()
    local matched_name value
    for matched_name in ${(on)matched_names}; do
        for value in ${(P)matched_name}; do
            values+=("$value")
        done
    done

    printf '%s\n' "${values[@]}"
}

ensure_brew_config_file() {
    if [[ "$BREW_CONFIG_FILE" == "$DEFAULT_BREW_CONFIG_FILE" ]]; then
        return 0
    fi

    if [[ ! -f "$BREW_CONFIG_FILE" ]]; then
        cp "$DEFAULT_BREW_CONFIG_FILE" "$BREW_CONFIG_FILE"
        info "已初始化用户配置文件: $BREW_CONFIG_FILE"
    fi
}

precheck() {
    print_header "系统环境预检"

    ensure_brew_config_file

    [[ ! -f $BREW_CONFIG_FILE ]] && log_fatal "缺失 Homebrew 配置文件: $BREW_CONFIG_FILE"
    require_macos_min_version "1015" "需要 macOS Catalina (10.15) 或更高版本"

    local free_space
    free_space="$(df -g / | tail -1 | awk '{print $4}')"
    [[ $free_space -lt 15 ]] && log_fatal "磁盘空间不足15GB (剩余: ${free_space}GB)"

    check_network_reachability "https://mirrors.ustc.edu.cn" "223.5.5.5" || \
        log_fatal "中科大源异常，网络连接失败，请检查网络设置"

    require_command brew
    success "系统环境预检通过"
}

configure_homebrew() {
    print_header "校准 Homebrew 配置"

    local brew_bin
    brew_bin="$(resolve_homebrew_bin)" || log_fatal "brew 未安装，请先安装 Homebrew"
    configure_homebrew_environment "$brew_bin"
}

install_formulae_packages() {
    local -a formulae=("$@")

    if [[ ${#formulae[@]} -eq 0 ]]; then
        info "未在配置中检测到 Formulae 项"
        return 0
    fi

    log_time_start "brew_formulae" "安装 ${#formulae[@]} 个 Homebrew Formulae"
    if bh_install_packages --formulae --retries 2 --label "Homebrew Formulae" "${formulae[@]}"; then
        log_time_end "brew_formulae" "Formulae 安装" "success"
        return 0
    fi

    log_time_end "brew_formulae" "Formulae 安装" "warn"
    return 1
}

install_cask_packages() {
    local -a casks=("$@")

    if [[ ${#casks[@]} -eq 0 ]]; then
        info "未在配置中检测到 Cask 项"
        return 0
    fi

    log_time_start "brew_casks" "安装 ${#casks[@]} 个 Homebrew Casks"
    if bh_install_packages --cask --retries 2 --label "Homebrew Casks" "${casks[@]}"; then
        log_time_end "brew_casks" "Cask 安装" "success"
        return 0
    fi

    log_time_end "brew_casks" "Cask 安装" "warn"
    return 1
}

report_core_software_result() {
    local install_failed="$1"

    bh_print_summary "核心软件安装报告"

    if [[ "$install_failed" == "true" ]]; then
        warning "部分 Homebrew 包安装失败，请查看上方失败列表并手动处理。"
    else
        success "核心软件安装完成"
    fi
}

install_core_software() {
    print_header "安装核心开发工具"

    source "$BREW_CONFIG_FILE"

    bh_reset_summary

    local install_failed=false
    local all_formulae=("${(@f)$(collect_configured_package_values "FORMULAE_")}")
    local all_casks=("${(@f)$(collect_configured_package_values "CASKS_")}")

    install_formulae_packages "${all_formulae[@]}" || install_failed=true
    install_cask_packages "${all_casks[@]}" || install_failed=true

    report_core_software_result "$install_failed"
}

run_setup_workflow() {
    precheck
    ensure_xcode_cli_installed
    configure_homebrew

    install_node
    install_python
    install_ruby
    install_go
    config_android_and_java

    install_core_software

    post_verification
    print_setup_completion
}
