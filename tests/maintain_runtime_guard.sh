#!/bin/zsh
# filepath: tests/maintain_runtime_guard.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS_COUNT=0

pass() {
  printf '[PASS] %s\n' "$1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local name="$3"

  if [[ "$actual" != "$expected" ]]; then
    printf 'expected: %s\nactual:   %s\n' "$expected" "$actual" >&2
    fail "$name"
  fi

  pass "$name"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local name="$3"

  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'missing substring: %s\noutput: %s\n' "$needle" "$haystack" >&2
    fail "$name"
  fi

  pass "$name"
}

info() { printf 'INFO:%s\n' "$*"; }
warning() { printf 'WARN:%s\n' "$*"; }
error() { printf 'ERROR:%s\n' "$*" >&2; }
print_header() { printf 'HEADER:%s\n' "$1"; }
print_code() { printf 'CODE:%s\n' "$1"; }
print_table_row() { printf 'TABLE:%s=%s\n' "$1" "$2"; }
success() { printf 'SUCCESS:%s\n' "$*"; }
log_time_start() { printf 'TIME_START:%s|%s\n' "$1" "$2"; }
log_time_end() { printf 'TIME_END:%s|%s|%s\n' "$1" "$2" "${3:-ok}"; }
log_fatal() {
  printf 'FATAL:%s\n' "$*" >&2
  return 1
}
confirm() { return 0; }

# shellcheck disable=SC1091
source "$REPO_ROOT/maintain/lib/command_runtime.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/maintain/lib/brew_updater_runtime.sh"

test_command_preview() {
  local preview
  preview="$(command_preview brew upgrade --cask visual-studio-code)"
  assert_eq "$preview" "brew upgrade --cask visual-studio-code" "command_preview joins args with spaces"
}

test_run_logged_command_dry_run() {
  local output=""
  local marker
  marker="$(mktemp "${TMPDIR:-/tmp}/maintain-runtime-marker.XXXXXX")"
  rm -f "$marker"

  DRY_RUN="true"
  fake_exec() {
    : > "$marker"
  }

  output="$(run_logged_command "执行假命令" fake_exec)"
  [[ ! -e "$marker" ]] || fail "run_logged_command dry-run skips execution"
  pass "run_logged_command dry-run skips execution"

  assert_contains "$output" "INFO:[dry-run] 执行假命令" "run_logged_command dry-run prints description"
  assert_contains "$output" "CODE:fake_exec" "run_logged_command dry-run prints command"
}

test_announce_brew_updater_context() {
  DRY_RUN="false"
  FORCE_CASKS="false"
  ERROR_LOG="/tmp/brew-update-errors.log"

  local output=""
  output="$(announce_brew_updater_context)"
  assert_contains "$output" "HEADER:Homebrew 维护工具" "announce context prints header"
  assert_contains "$output" "INFO:错误日志位置: $ERROR_LOG" "announce context prints error log"
}

test_run_brew_updater_workflow_skip_flags() {
  local calls=()
  local output=""
  local output_file
  output_file="$(mktemp "${TMPDIR:-/tmp}/maintain-runtime-output.XXXXXX")"

  run_homebrew_update() { calls+=("update"); }
  run_formulae_upgrade() { calls+=("formulae"); }
  run_cask_upgrades() { calls+=("casks"); }
  run_cleanup() { calls+=("cleanup"); }
  warning() { printf 'WARN:%s\n' "$*"; }

  SKIP_FORMULAE="true"
  SKIP_CASKS="true"
  SKIP_CLEANUP="true"

  run_brew_updater_workflow > "$output_file"
  output="$(cat "$output_file")"
  rm -f "$output_file"
  assert_eq "${calls[*]}" "update" "workflow only runs required step when all optional phases are skipped"
  assert_contains "$output" "WARN:已跳过 Formulae 更新" "workflow reports skipped formulae"
  assert_contains "$output" "WARN:已跳过 Cask 更新" "workflow reports skipped casks"
  assert_contains "$output" "WARN:已跳过缓存清理" "workflow reports skipped cleanup"
}

main() {
  cd "$REPO_ROOT"

  test_command_preview
  test_run_logged_command_dry_run
  test_announce_brew_updater_context
  test_run_brew_updater_workflow_skip_flags

  printf '\nMaintain runtime guard passed: %d\n' "$PASS_COUNT"
}

main "$@"
