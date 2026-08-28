#!/bin/bash
# filepath: tests/e2e/e2e_lib.sh
# E2E 共享辅助库：沙箱隔离、命令桩 PATH、transcript 记录与断言。
#
# 设计要点：
#   - 每个用例脚本 source 本文件后调用 e2e_begin <name>，末尾调用 e2e_summary。
#   - 沙箱：HOME / MACOS_SCRIPTS_CONFIG_DIR / MACOS_SCRIPTS_LOG_DIR /
#     MACOS_SCRIPTS_LAUNCH_AGENTS_DIR 全部指向临时目录，PATH 前置 shims/。
#   - transcript：tests/e2e/shims/ 下的命令桩把每次外部调用追加到 $E2E_TRANSCRIPT，
#     用例据此断言“脚本实际执行了什么”，而非只验证不报错。

# 本文件为共享库：大量变量由子脚本/命令桩跨进程消费，文件内看似未使用。
# shellcheck disable=SC2034

set -euo pipefail

E2E_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$E2E_DIR/../.." && pwd)"
E2E_SHIMS_DIR="$E2E_DIR/shims"

E2E_TMP_ROOT=""
E2E_HOME=""
E2E_CONFIG_DIR=""
E2E_LOG_DIR=""
E2E_LAUNCH_AGENTS_DIR=""
E2E_TRANSCRIPT=""
E2E_TEST_NAME=""
E2E_PASS_COUNT=0
E2E_FAIL_COUNT=0

# 最近一次 e2e_run 的结果
E2E_RUN_DESC=""
E2E_RUN_OUTPUT=""
E2E_RUN_STATUS=0

e2e_begin() {
  E2E_TEST_NAME="${1:-unnamed}"
  E2E_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/macos-scripts-e2e.XXXXXX")"
  E2E_HOME="$E2E_TMP_ROOT/home"
  E2E_CONFIG_DIR="$E2E_TMP_ROOT/config"
  E2E_LOG_DIR="$E2E_TMP_ROOT/logs"
  E2E_LAUNCH_AGENTS_DIR="$E2E_TMP_ROOT/launch_agents"
  E2E_TRANSCRIPT="$E2E_TMP_ROOT/transcript.log"

  mkdir -p "$E2E_HOME" "$E2E_CONFIG_DIR" "$E2E_LOG_DIR" "$E2E_LAUNCH_AGENTS_DIR"
  export HOME="$E2E_HOME"
  export MACOS_SCRIPTS_CONFIG_DIR="$E2E_CONFIG_DIR"
  export MACOS_SCRIPTS_LOG_DIR="$E2E_LOG_DIR"
  export MACOS_SCRIPTS_LAUNCH_AGENTS_DIR="$E2E_LAUNCH_AGENTS_DIR"
  export E2E_TMP_ROOT
  export E2E_TRANSCRIPT
  export PATH="$E2E_SHIMS_DIR:$PATH"

  : > "$E2E_TRANSCRIPT"
  trap e2e_teardown EXIT
}

e2e_teardown() {
  if [[ -n "${E2E_TMP_ROOT:-}" && -d "$E2E_TMP_ROOT" ]]; then
    rm -rf "$E2E_TMP_ROOT"
  fi
}

e2e_pass() {
  printf '[PASS] %s\n' "$1"
  E2E_PASS_COUNT=$((E2E_PASS_COUNT + 1))
}

e2e_fail() {
  printf '[FAIL] %s\n' "$1" >&2
  E2E_FAIL_COUNT=$((E2E_FAIL_COUNT + 1))
}

# 执行命令并捕获 stdout+stderr 与退出码（不因失败退出）。
e2e_run() {
  local desc="$1"
  shift
  E2E_RUN_DESC="$desc"
  set +e
  E2E_RUN_OUTPUT="$("$@" 2>&1)"
  E2E_RUN_STATUS=$?
  set -e
}

e2e_run_expect_success() {
  local desc="$1"
  shift
  e2e_run "$desc" "$@"
  if [[ "$E2E_RUN_STATUS" -ne 0 ]]; then
    printf 'command failed (exit=%d): %s\n' "$E2E_RUN_STATUS" "$desc" >&2
    printf '%s\n' "$E2E_RUN_OUTPUT" >&2
    e2e_fail "$desc"
  else
    e2e_pass "$desc"
  fi
}

e2e_run_expect_failure() {
  local desc="$1"
  shift
  e2e_run "$desc" "$@"
  if [[ "$E2E_RUN_STATUS" -eq 0 ]]; then
    printf 'command unexpectedly succeeded: %s\n' "$desc" >&2
    printf '%s\n' "$E2E_RUN_OUTPUT" >&2
    e2e_fail "$desc"
  else
    e2e_pass "$desc"
  fi
}

e2e_assert_eq() {
  local actual="$1"
  local expected="$2"
  local name="$3"
  if [[ "$actual" == "$expected" ]]; then
    e2e_pass "$name"
  else
    printf 'expected: %s\nactual:   %s\n' "$expected" "$actual" >&2
    e2e_fail "$name"
  fi
}

e2e_assert_contains() {
  local haystack="$1"
  local needle="$2"
  local name="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    e2e_pass "$name"
  else
    printf 'missing substring: %s\noutput: %s\n' "$needle" "$haystack" >&2
    e2e_fail "$name"
  fi
}

e2e_assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local name="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    e2e_pass "$name"
  else
    printf 'unexpected substring: %s\noutput: %s\n' "$needle" "$haystack" >&2
    e2e_fail "$name"
  fi
}

e2e_assert_file() {
  local path="$1"
  local name="$2"
  if [[ -f "$path" ]]; then
    e2e_pass "$name"
  else
    printf 'missing file: %s\n' "$path" >&2
    e2e_fail "$name"
  fi
}

e2e_assert_not_file() {
  local path="$1"
  local name="$2"
  if [[ ! -f "$path" ]]; then
    e2e_pass "$name"
  else
    printf 'unexpected file: %s\n' "$path" >&2
    e2e_fail "$name"
  fi
}

e2e_assert_dir() {
  local path="$1"
  local name="$2"
  if [[ -d "$path" ]]; then
    e2e_pass "$name"
  else
    printf 'missing dir: %s\n' "$path" >&2
    e2e_fail "$name"
  fi
}

e2e_assert_file_contains() {
  local path="$1"
  local needle="$2"
  local name="$3"
  if [[ ! -f "$path" ]]; then
    printf 'missing file: %s\n' "$path" >&2
    e2e_fail "$name"
    return
  fi
  if grep -qF -- "$needle" "$path"; then
    e2e_pass "$name"
  else
    printf 'missing substring in %s: %s\n' "$path" "$needle" >&2
    e2e_fail "$name"
  fi
}

e2e_assert_transcript_contains() {
  local needle="$1"
  local name="$2"
  e2e_assert_file_contains "$E2E_TRANSCRIPT" "$needle" "$name"
}

e2e_assert_transcript_not_contains() {
  local needle="$1"
  local name="$2"
  if [[ ! -f "$E2E_TRANSCRIPT" ]]; then
    e2e_pass "$name"
    return
  fi
  if ! grep -qF -- "$needle" "$E2E_TRANSCRIPT"; then
    e2e_pass "$name"
  else
    printf 'unexpected in transcript: %s\n' "$needle" >&2
    e2e_fail "$name"
  fi
}

# 断言 transcript 中多个调用按给定顺序出现（允许中间夹其他调用）。
e2e_assert_transcript_order() {
  local name="$1"
  shift
  local prev=0
  local needle
  local line_no
  for needle in "$@"; do
    line_no="$(awk -v n="$needle" 'index($0, n) { print NR; exit }' "$E2E_TRANSCRIPT")"
    if [[ -z "$line_no" ]]; then
      printf 'transcript missing: %s\n' "$needle" >&2
      e2e_fail "$name"
      return
    fi
    if [[ "$line_no" -lt "$prev" ]]; then
      printf 'transcript order wrong: %s (line %s < %s)\n' "$needle" "$line_no" "$prev" >&2
      e2e_fail "$name"
      return
    fi
    prev="$line_no"
  done
  e2e_pass "$name"
}

e2e_summary() {
  printf '\n[%s] PASS=%d FAIL=%d\n' "$E2E_TEST_NAME" "$E2E_PASS_COUNT" "$E2E_FAIL_COUNT"
  [[ "$E2E_FAIL_COUNT" -eq 0 ]]
}
