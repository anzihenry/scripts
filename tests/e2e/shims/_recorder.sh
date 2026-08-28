#!/bin/bash
# filepath: tests/e2e/shims/_recorder.sh
# 命令桩公共记录器：把每次外部调用追加到 $E2E_TRANSCRIPT，供 E2E 断言。
# 由 tests/e2e/shims/ 下的各命令桩 source 使用，自身不作为可执行命令。
record_invocation() {
  [[ -n "${E2E_TRANSCRIPT:-}" ]] || return 0
  {
    printf '%s' "$(basename "$0")"
    for arg in "$@"; do
      printf ' %q' "$arg"
    done
    printf '\n'
  } >> "$E2E_TRANSCRIPT"
}
