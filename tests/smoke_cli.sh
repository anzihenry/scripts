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

  printf '\nSmoke tests passed: %d\n' "$PASS_COUNT"
}

main "$@"
