#!/bin/zsh
# filepath: tests/smoke_cli.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/macos-scripts-smoke.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

export MACOS_SCRIPTS_LOG_DIR="$TMP_ROOT/logs"
export MACOS_SCRIPTS_CONFIG_DIR="$TMP_ROOT/config"

PASS_COUNT=0

pass() {
  printf '[PASS] %s\n' "$1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

run_expect_success_contains() {
  local name="$1"
  local pattern="$2"
  shift 2
  local output

  if ! output="$("$@" 2>&1)"; then
    printf '%s\n' "$output" >&2
    fail "$name"
  fi

  if [[ "$output" != *"$pattern"* ]]; then
    printf '%s\n' "$output" >&2
    fail "$name"
  fi

  pass "$name"
}

run_expect_failure_contains() {
  local name="$1"
  local pattern="$2"
  shift 2
  local output

  set +e
  output="$("$@" 2>&1)"
  local command_status=$?
  set -e

  if [[ $command_status -eq 0 ]]; then
    printf '%s\n' "$output" >&2
    fail "$name"
  fi

  if [[ "$output" != *"$pattern"* ]]; then
    printf '%s\n' "$output" >&2
    fail "$name"
  fi

  pass "$name"
}

main() {
  cd "$REPO_ROOT"

  run_expect_success_contains \
    "CLI help" \
    "一级命令:" \
    zsh bin/macos-scripts --help

  run_expect_success_contains \
    "Lint help" \
    "用法:" \
    zsh bin/macos-scripts lint help

  run_expect_success_contains \
    "Help setup topic" \
    "macos-scripts setup github [参数]" \
    zsh bin/macos-scripts help setup

  run_expect_success_contains \
    "Help maintain installer topic" \
    "macos-scripts maintain installer download" \
    zsh bin/macos-scripts help maintain installer

  # maintain brew --dry-run 会真实执行脚本并校验 brew 存在；
  # 本机未安装 brew 时跳过该用例，避免最小回归依赖外部命令。
  if command -v brew > /dev/null 2>&1; then
    run_expect_success_contains \
      "Maintain brew dry-run" \
      "Homebrew 维护完成" \
      zsh bin/macos-scripts maintain brew --dry-run
  else
    printf '[SKIP] Maintain brew dry-run（本机未安装 brew）\n'
  fi

  run_expect_failure_contains \
    "Release verify missing tag" \
    "release verify 需要提供版本 tag" \
    zsh bin/macos-scripts release verify

  run_expect_failure_contains \
    "Setup github rejects custom domain" \
    "setup github 固定使用 github.com" \
    zsh bin/macos-scripts setup github --domain example.com

  run_expect_failure_contains \
    "Setup shell rejects extra args" \
    "该命令不接受额外参数: unexpected" \
    zsh bin/macos-scripts setup shell unexpected

  run_expect_failure_contains \
    "Maintain brew rejects unsupported arg" \
    "maintain brew 不支持参数: --bogus" \
    zsh bin/macos-scripts maintain brew --bogus

  run_expect_failure_contains \
    "Release verify rejects unsupported arg" \
    "release verify 不支持参数: --bogus" \
    zsh bin/macos-scripts release verify v0.3.0 --bogus

  run_expect_failure_contains \
    "Removed job command is rejected" \
    "未知命令: job" \
    zsh bin/macos-scripts job list

  run_expect_failure_contains \
    "Removed job help topic is rejected" \
    "未知的帮助主题: job" \
    zsh bin/macos-scripts help job

  local help_output
  help_output="$(zsh bin/macos-scripts --help)"
  [[ "$help_output" != *launchd* && "$help_output" != *'macos-scripts job'* ]] || fail "CLI help advertises removed jobs"
  pass "CLI help omits removed scheduling feature"

  printf '\nSmoke tests passed: %d\n' "$PASS_COUNT"
}

main "$@"
