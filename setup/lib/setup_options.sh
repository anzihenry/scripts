#!/bin/zsh
# filepath: setup/lib/setup_options.sh
# CLI 与独立脚本共享解析；解析参数不产生文件或外部命令副作用。
parse_setup_options() {
    SETUP_DRY_RUN=false
    SETUP_HELP=false
    SETUP_MODULES=(node python ruby go android packages)
    local module value
    while (( $# > 0 )); do
        case "$1" in
            --dry-run) SETUP_DRY_RUN=true; shift ;;
            --modules)
                (( $# >= 2 )) || { error "--modules 需要逗号分隔的模块列表"; return 2; }
                value="$2"
                [[ -n "$value" && "$value" != ,* && "$value" != *, && "$value" != *,,* ]] || { error "模块列表不能为空"; return 2; }
                SETUP_MODULES=("${(@s:,:)value}")
                for module in "${SETUP_MODULES[@]}"; do
                    case "$module" in node|python|ruby|go|android|packages) ;; *) error "未知模块: $module"; return 2 ;; esac
                done
                SETUP_MODULES=("${(@u)SETUP_MODULES}")
                shift 2 ;;
            -h|--help|help) SETUP_HELP=true; shift ;;
            *) error "未知参数: $1"; return 2 ;;
        esac
    done
}

setup_module_enabled() {
    # 保留直接调用库函数的默认行为。
    (( ${+SETUP_MODULES} == 0 )) && return 0
    (( ${SETUP_MODULES[(Ie)$1]} > 0 ))
}

parse_shell_options() {
    SETUP_DRY_RUN=false
    SETUP_HELP=false
    while (( $# > 0 )); do
        case "$1" in
            --dry-run) SETUP_DRY_RUN=true ;;
            -h|--help|help) SETUP_HELP=true ;;
            *) error "未知参数: $1"; return 2 ;;
        esac
        shift
    done
}
