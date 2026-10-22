#!/bin/zsh
# filepath: lib/workflow.sh
# 参数为「阶段名称 函数名」成对列表；函数必须显式传播内部失败。
run_stages() {
    local label action code index=0 total=$(($# / 2))
    local -a completed=() pending=()
    (( $# % 2 == 0 )) || return 2
    while (( $# > 0 )); do
        label="$1" action="$2"
        shift 2
        index=$((index + 1))
        info "阶段 $index/$total: $label"
        log_time_start "workflow_$index" "$label"
        code=0
        "$action" || code=$?
        if (( code != 0 )); then
            log_time_end "workflow_$index" "$label" error
            while (( $# > 0 )); do pending+=("$1"); shift 2; done
            error "运行失败: $label（退出码 $code）"
            info "已完成: ${completed[*]:-无}"
            info "未执行: ${pending[*]:-无}"
            warning "已完成的软件安装保留；修复上述错误后重新运行原命令，会重新检查实际状态。"
            return "$code"
        fi
        completed+=("$label")
        log_time_end "workflow_$index" "$label" success
    done
    success "阶段完成: ${completed[*]:-无}"
}
