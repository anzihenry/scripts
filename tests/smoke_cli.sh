#!/bin/bash
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
  local status=$?
  set -e

  if [[ $status -eq 0 ]]; then
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
    "Maintain brew dry-run" \
    "Homebrew 维护完成" \
    zsh bin/macos-scripts maintain brew --dry-run

  run_expect_failure_contains \
    "Release verify missing tag" \
    "release verify 需要提供版本 tag" \
    zsh bin/macos-scripts release verify

  run_expect_failure_contains \
    "Setup github rejects custom domain" \
    "setup github 固定使用 github.com" \
    zsh bin/macos-scripts setup github --domain example.com

  run_expect_success_contains \
    "Job list" \
    "列出当前用户的脚本任务" \
    zsh bin/macos-scripts job list

  run_expect_success_contains \
    "Job disable dry-run" \
    "将执行: launchctl disable" \
    zsh bin/macos-scripts job disable --job-name smoke-refactor --dry-run

  run_expect_success_contains \
    "Job create dry-run forwards args" \
    "创建任务 smoke-refactor，耗时" \
    zsh bin/macos-scripts job create --job-name smoke-refactor --script ./lint/lint_shell.sh --interval 5 --dry-run -- --demo value

  run_expect_failure_contains \
    "Job create missing script" \
    "job create 需要提供 --script" \
    zsh bin/macos-scripts job create --job-name smoke-refactor --interval 5 --dry-run

  run_expect_failure_contains \
    "Job create invalid interval" \
    "--interval 需要正整数" \
    zsh bin/macos-scripts job create --job-name smoke-refactor --script ./lint/lint_shell.sh --interval abc --dry-run

  run_expect_failure_contains \
    "Job create rejects stray args before separator" \
    "job create 不支持参数: name" \
    zsh bin/macos-scripts job create --job-name bad name --script ./lint/lint_shell.sh --interval 5 --dry-run

  printf '\nSmoke tests passed: %d\n' "$PASS_COUNT"
}

main "$@"
