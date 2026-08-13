#!/bin/zsh
# filepath: tests/job_plist_guard.sh
# 集成测试：真实写入 plist 文件并断言 plutil -lint 通过。
# 覆盖 compose_plist / write_plist_file 的实际产物，防止
# "字面 \\n 导致 plist 无效" 这类仅靠函数级 mock 无法发现的回归。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/macos-scripts-job-plist.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

# 隔离 LaunchAgents 与日志目录，避免污染真实环境
export MACOS_SCRIPTS_LAUNCH_AGENTS_DIR="$TMP_ROOT/LaunchAgents"
export MACOS_SCRIPTS_LOG_DIR="$TMP_ROOT/logs"

# shellcheck disable=SC1091
source "$REPO_ROOT/job/lib/job_paths.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/job/lib/job_plist.sh"

# 测试所需的日志函数（colors.sh 中同名函数为 zsh/bash 兼容实现）
info() { printf 'INFO:%s\n' "$*"; }
warning() { printf 'WARN:%s\n' "$*"; }
error() { printf 'ERROR:%s\n' "$*" >&2; }
success() { printf 'SUCCESS:%s\n' "$*"; }

PASS_COUNT=0

pass() {
  printf '[PASS] %s\n' "$1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
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

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local name="$3"

  if [[ "$haystack" == *"$needle"* ]]; then
    printf 'unexpected substring: %s\noutput: %s\n' "$needle" "$haystack" >&2
    fail "$name"
  fi
  pass "$name"
}

test_real_plist_write_interval() {
  local job_name="plist-guard-interval"
  local plist_path
  plist_path="$(get_plist_path "$job_name")"

  local program_block schedule_block plist_content
  ensure_job_directories
  program_block="$(compose_program_arguments "/tmp/test.sh" "--demo" "value")"
  schedule_block="$(compose_schedule_block "5" "" "")"
  plist_content="$(compose_plist "$(get_label "$job_name")" "$REPO_ROOT" "$LOG_BASE_DIR/${job_name}.out.log" "$LOG_BASE_DIR/${job_name}.err.log" "1" "0" "$schedule_block" "$program_block")"

  write_plist_file "$plist_path" "$plist_content"

  [[ -f "$plist_path" ]] || fail "plist file was written to disk"
  pass "plist file written to $plist_path"

  plutil -lint "$plist_path" > /dev/null 2>&1 || {
    printf 'plutil -lint failed for %s\n' "$plist_path" >&2
    fail "plutil -lint accepts generated interval plist"
  }
  pass "plutil -lint accepts generated interval plist"

  # 关键回归断言：不允许出现字面 \n（P0-1 bug）
  local content
  content="$(<"$plist_path")"
  assert_not_contains "$content" '\n' "no literal backslash-n in written plist"
  assert_contains "$content" "<integer>300</integer>" "interval converted to seconds in plist"
  assert_contains "$content" "<key>KeepAlive</key>" "keepalive flag appears in plist"
}

test_real_plist_write_calendar() {
  local job_name="plist-guard-calendar"
  local plist_path
  plist_path="$(get_plist_path "$job_name")"

  local program_block schedule_block plist_content
  ensure_job_directories
  program_block="$(compose_program_arguments "/tmp/test.sh" "--at" "08:30")"
  schedule_block="$(compose_schedule_block "" "08:30" "1")"
  plist_content="$(compose_plist "$(get_label "$job_name")" "$REPO_ROOT" "$LOG_BASE_DIR/${job_name}.out.log" "$LOG_BASE_DIR/${job_name}.err.log" "0" "1" "$schedule_block" "$program_block")"

  write_plist_file "$plist_path" "$plist_content"

  plutil -lint "$plist_path" > /dev/null 2>&1 || {
    printf 'plutil -lint failed for %s\n' "$plist_path" >&2
    fail "plutil -lint accepts generated calendar plist"
  }
  pass "plutil -lint accepts generated calendar plist"

  local content
  content="$(<"$plist_path")"
  assert_contains "$content" "<key>Hour</key>" "calendar hour present"
  assert_contains "$content" "<integer>8</integer>" "hour normalized without leading zero"
  assert_contains "$content" "<key>Weekday</key>" "weekday present"
  assert_contains "$content" "<key>Disabled</key>" "disabled flag appears in plist"
}

main() {
  cd "$REPO_ROOT"

  test_real_plist_write_interval
  test_real_plist_write_calendar

  printf '\nJob plist guard passed: %d\n' "$PASS_COUNT"
}

main "$@"
