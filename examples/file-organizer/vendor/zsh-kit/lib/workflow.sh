#!/bin/zsh
# filepath: packages/zsh-kit/lib/workflow.sh
source "${${(%):-%x}:A:h}/console.sh"
# 参数为「阶段名称 函数名」成对列表；函数必须显式传播内部失败。
sk_run_stages() {
    local label action code index=0 total=$(($# / 2))
    local -a completed=() pending=()
    (( $# % 2 == 0 )) || return 2
    while (( $# > 0 )); do
        label="$1" action="$2"
        shift 2
        index=$((index + 1))
        sk_info "阶段 $index/$total: $label"
        sk_time_start "workflow_$index" "$label"
        code=0
        "$action" || code=$?
        if (( code != 0 )); then
            sk_time_end "workflow_$index" "$label" error
            while (( $# > 0 )); do pending+=("$1"); shift 2; done
            sk_error "运行失败: $label（退出码 $code）"
            sk_info "已完成: ${completed[*]:-无}"
            sk_info "未执行: ${pending[*]:-无}"
            [[ -z "${SK_RECOVERY_MESSAGE:-}" ]] || sk_warning "$SK_RECOVERY_MESSAGE"
            return "$code"
        fi
        completed+=("$label")
        sk_time_end "workflow_$index" "$label" success
    done
    sk_success "阶段完成: ${completed[*]:-无}"
}
