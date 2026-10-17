#!/bin/zsh
# filepath: tests/e2e/shims/_recorder.sh
# 命令桩公共记录器：把每次外部调用追加到 ${E2E_TRANSCRIPT}，供 E2E 断言。
# 由 tests/e2e/shims/ 下的各命令桩 source 使用，自身不作为可执行命令。
set -u

# Zsh 的 $0 随函数/source 改变；ZSH_ARGZERO 保留入口脚本名称。
E2E_SHIM_NAME="${ZSH_ARGZERO:t}"

record_invocation() {
  [[ -n "${E2E_TRANSCRIPT:-}" ]] || return 0
  {
    printf '%s' "$E2E_SHIM_NAME"
    for arg in "$@"; do
      printf ' %q' "$arg"
    done
    printf '\n'
  } >> "$E2E_TRANSCRIPT"
}
