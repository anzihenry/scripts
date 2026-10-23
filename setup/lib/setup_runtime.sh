#!/bin/zsh
# filepath: setup/lib/setup_runtime.sh
source "${${(%):-%x}:A:h}/setup_options.sh"
source "${${(%):-%x}:A:h}/../../lib/workflow.sh"

initialize_setup_context() {
    SETUP_LOG_FILE="$(prepare_log_file_path "macos-setup.log")" || return 1
    enable_log_capture "$SETUP_LOG_FILE" || return 1

    DEFAULT_BREW_CONFIG_FILE="${SCRIPT_DIR}/brew.conf.sh"

    if [[ -n "${MACOS_SCRIPTS_CONFIG_DIR:-}" ]]; then
        mkdir -p "$MACOS_SCRIPTS_CONFIG_DIR" || return 1
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
        cp "$DEFAULT_BREW_CONFIG_FILE" "$BREW_CONFIG_FILE" || return 1
        info "已初始化用户配置文件: $BREW_CONFIG_FILE"
    fi
}

ensure_setup_brew_config_ready() {
    ensure_brew_config_file || return $?
    # 必须用 if 而不是 `[[ ... ]] && log_fatal ...`：后者在条件为假时会让
    # 函数返回 1，配合调用方的 set -e 会把成功路径也判为失败。
    if [[ ! -f "$BREW_CONFIG_FILE" ]]; then
        error "缺失 Homebrew 配置文件: $BREW_CONFIG_FILE"
        return 1
    fi
}

verify_setup_platform_requirements() {
    require_supported_macos || return 1

    local free_space
    free_space="$(df -g / | tail -1 | awk '{print $4}')"
    if [[ ! "$free_space" =~ ^[0-9]+$ ]]; then
        error "无法解析根分区可用空间（df 输出: ${free_space:-空}）"
        return 1
    fi
    if [[ $free_space -lt 15 ]]; then
        error "磁盘空间不足15GB (剩余: ${free_space}GB)"
        return 1
    fi
}

verify_setup_network_access() {
    check_network_reachability "https://mirrors.ustc.edu.cn" "223.5.5.5" || \
        { error "中科大源异常，网络连接失败，请检查网络设置"; return 1; }
}

verify_setup_brew_command_available() {
    command -v brew >/dev/null 2>&1 || { error "brew 未安装，请先运行 bootstrap/install.sh"; return 1; }
}

precheck() {
    print_header "系统环境预检"

    verify_setup_platform_requirements || return $?
    ensure_setup_brew_config_ready || return $?
    verify_setup_network_access || return $?
    verify_setup_brew_command_available || return $?

    success "系统环境预检通过"
}

configure_homebrew() {
    print_header "校准 Homebrew 配置"

    local brew_bin
    brew_bin="$(resolve_homebrew_bin)" || { error "brew 未安装，请先安装 Homebrew"; return 1; }
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
        warning "部分 Homebrew 包安装失败，请查看上方失败列表并重新运行。"
        return 1
    else
        success "核心软件安装完成"
    fi
}

install_core_software() {
    print_header "安装核心开发工具"

    setup_module_enabled packages || { info "跳过未选择模块: packages"; return 0; }
    source "$BREW_CONFIG_FILE" || return 1

    bh_reset_summary

    local install_failed=false
    local all_formulae=("${(@f)$(collect_configured_package_values "FORMULAE_")}")
    local all_casks=("${(@f)$(collect_configured_package_values "CASKS_")}")

    install_formulae_packages "${all_formulae[@]}" || install_failed=true
    install_cask_packages "${all_casks[@]}" || install_failed=true

    report_core_software_result "$install_failed"
}

run_language_environment_setup() {
    local module action
    for module in node python ruby go android; do
        if ! setup_module_enabled "$module"; then
            info "跳过未选择模块: $module"
            continue
        fi
        action="install_$module"
        [[ "$module" != android ]] || action=config_android_and_java
        "$action" || return $?
    done
}

run_setup_completion_checks() {
    post_verification || return $?
    print_setup_completion
}

run_setup_workflow() {
    run_stages 预检 precheck 开发工具 ensure_xcode_cli_installed Homebrew configure_homebrew \
        语言环境 run_language_environment_setup 软件包 install_core_software 验证 run_setup_completion_checks
}

preview_setup() {
    info "[dry-run] 选择模块: ${SETUP_MODULES[*]}"
    info "[dry-run] 将校准 Homebrew（USTC）并检查 Command Line Tools。"
    local module
    for module in "${SETUP_MODULES[@]}"; do
        if [[ "$module" == packages ]]; then
            local config="${MACOS_SCRIPTS_CONFIG_DIR:-$SCRIPT_DIR}/brew.conf.sh"
            [[ -f "$config" ]] || config="$SCRIPT_DIR/brew.conf.sh"
            info "[dry-run] 将按配置安装软件包: $config（预览不执行配置脚本）"
            cat "$config" || return 1
        else
            info "[dry-run] 将检查/安装 $module，更新 ~/.zshrc 对应配置块。"
        fi
    done
    setup_module_enabled python && info "[dry-run] pip 配置: $SETUP_PIP_INDEX（~/.pip/pip.conf）"
    setup_module_enabled node && info "[dry-run] npm registry: $SETUP_NPM_REGISTRY；保留已有本地 LTS。"
    setup_module_enabled ruby && info "[dry-run] gem 源: $SETUP_GEM_SOURCE"
    setup_module_enabled go && info "[dry-run] GOPATH: $SETUP_GOPATH；GOPROXY: $SETUP_GOPROXY"
    setup_module_enabled android && info "[dry-run] JAVA_HOME: $SETUP_JAVA_HOME；ANDROID_HOME: $SETUP_ANDROID_HOME"
    return 0
}
