#!/bin/zsh
# filepath: lib/workflow.sh
source "${${(%):-%x}:A:h}/../packages/zsh-kit/lib/workflow.sh"
run_stages() {
    local SK_RECOVERY_MESSAGE="已完成的软件安装保留；修复上述错误后重新运行原命令，会重新检查实际状态。"
    sk_run_stages "$@"
}
