#!/bin/zsh
# filepath: tests/bootstrap_guard.sh
# 回归护栏：bootstrap/install.sh 的两种执行模式都必须可用。
#   1. 本地文件模式（zsh bootstrap/install.sh）
#   2. curl 管道模式（cat bootstrap/install.sh | zsh -s -- ...）
# 管道模式下 ${0:A} 无法解析真实路径、仓库文件不可用，脚本必须自包含运行。
# 此护栏防止再次出现 "source lib/utils.sh 失败导致管道模式整体退出" 的回归。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BOOTSTRAP="$REPO_ROOT/bootstrap/install.sh"

PASS_COUNT=0

pass() {
  printf '[PASS] %s\n' "$1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

# 用临时目录隔离日志输出（沙箱/真实环境均可写）
run_bootstrap_pipe() {
  local log_dir
  log_dir="$(mktemp -d "${TMPDIR:-/tmp}/macos-scripts-bootstrap.XXXXXX")"
  local out
  out="$(cat "$BOOTSTRAP" | MACOS_SCRIPTS_LOG_DIR="$log_dir" zsh -s -- "$@" 2>&1)"
  local exit_code=$?
  rm -rf "$log_dir"
  printf '%s' "$out"
  return $exit_code
}

main() {
  cd "$REPO_ROOT"

  local output=""

  # 1. 管道模式 --dry-run：应完整跑通流程（版本输出 0.4.0 行、不退出）
  output="$(run_bootstrap_pipe --dry-run --yes || true)"
  assert_contains() {
    if [[ "$output" != *"$1"* ]]; then
      printf 'missing substring: %s\noutput: %s\n' "$1" "$output" >&2
      fail "$2"
    fi
    pass "$2"
  }
  assert_contains "Bootstrap 预检" "pipe mode reaches precheck"
  assert_contains "安装 Homebrew" "pipe mode reaches homebrew step"
  assert_contains "brew install anzihenry/scripts/macos-scripts" "pipe mode reaches formula install step"
  assert_contains "0.4.0" "pipe mode uses version from VERSION env/default"

  # 2. 管道模式 --help：应输出帮助而非因 source 失败退出
  output="$(run_bootstrap_pipe --help || true)"
  assert_contains "用法:" "pipe mode help renders"
  assert_contains "--dry-run" "pipe mode help lists dry-run"

  # 3. 管道模式未知参数：应报错而非 source 崩溃
  output="$(run_bootstrap_pipe --bogus-flag || true)"
  assert_contains "未知参数" "pipe mode rejects unknown arg gracefully"

  printf '\nBootstrap guard passed: %d\n' "$PASS_COUNT"
}

main "$@"
