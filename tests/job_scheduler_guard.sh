#!/bin/zsh
# filepath: tests/job_scheduler_guard.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS_COUNT=0
JOB_SCHEDULER_SOURCE_ONLY=1
export JOB_SCHEDULER_SOURCE_ONLY

pass() { printf '[PASS] %s\n' "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { printf '[FAIL] %s\n' "$1" >&2; exit 1; }
assert_eq() { [[ "$1" == "$2" ]] || { printf 'expected: %s\nactual:   %s\n' "$2" "$1" >&2; fail "$3"; }; pass "$3"; }

info() { printf 'INFO:%s\n' "$*"; }
warning() { printf 'WARN:%s\n' "$*"; }
error() { printf 'ERROR:%s\n' "$*" >&2; }
success() { printf 'SUCCESS:%s\n' "$*"; }
highlight() { printf '%s\n' "$*"; }
print_usage() { printf 'USAGE:job scheduler\n'; }
require_command() { :; }

# shellcheck disable=SC1091
source "$REPO_ROOT/job/scheduler.sh"

test_execute_create_keeps_phase_order() {
  local calls=()

  job_timer_start() { calls+=("timer-start"); }
  ensure_job_directories() { calls+=("dirs"); }
  resolve_job_execution_context() { calls+=("context:$1"); JOB_ACTION_LABEL="label.$1"; JOB_ACTION_PLIST_PATH="/tmp/$1.plist"; }
  build_job_plist_content() { calls+=("build:$1"); printf 'plist-content'; }
  info() { calls+=("info:$1"); }
  ensure_job_plist_can_be_written() { calls+=("ensure:$1:$2"); }
  write_or_preview_job_plist() { calls+=("write:$1:$3"); }
  resolve_job_load_behavior() { calls+=("load-behavior:$1:$2"); printf '0'; }
  load_created_job_if_needed() { calls+=("load:$1:$2:$3:$4"); }
  job_timer_end() { calls+=("timer-end"); }

  execute_create demo /tmp/demo.sh 5 "" "" 0 /tmp /tmp/out.log /tmp/err.log 0 0 1 --foo

  assert_eq "${calls[*]}" \
    "timer-start dirs context:demo info:目标 plist 文件: /tmp/demo.plist ensure:/tmp/demo.plist:1 write:/tmp/demo.plist:1 load:/tmp/demo.plist:label.demo:0:1 timer-end" \
    "execute create keeps expected phase order"
}

test_execute_delete_keeps_phase_order() {
  local calls=()

  job_timer_start() { calls+=("timer-start"); }
  resolve_job_execution_context() { calls+=("context:$1"); JOB_ACTION_LABEL="label.$1"; JOB_ACTION_PLIST_PATH="/tmp/$1.plist"; }
  launchctl_bootout() { calls+=("bootout:$1:$2"); }
  info() { calls+=("info:$1"); }
  job_timer_end() { calls+=("timer-end:$3"); }

  local temp_plist
  temp_plist="$(mktemp "${TMPDIR:-/tmp}/job-scheduler-guard.XXXXXX")"
  JOB_ACTION_PLIST_PATH="$temp_plist"
  resolve_job_execution_context() { calls+=("context:$1"); JOB_ACTION_LABEL="label.$1"; JOB_ACTION_PLIST_PATH="$temp_plist"; }

  execute_delete demo 1

  rm -f "$temp_plist"
  assert_eq "${calls[*]}" \
    "timer-start context:demo bootout:label.demo:1 info:(dry-run) 将移除: $temp_plist timer-end:success" \
    "execute delete keeps expected phase order"
}

test_execute_enable_uses_shared_context() {
  local calls=()

  resolve_job_execution_context() { calls+=("context:$1"); JOB_ACTION_LABEL="label.$1"; JOB_ACTION_PLIST_PATH="/tmp/$1.plist"; }
  ensure_job_plist_exists_for_action() { calls+=("ensure:$1"); }
  launchctl_bootstrap() { calls+=("bootstrap:$1:$2:$3"); }
  success() { calls+=("success:$1"); }

  execute_enable demo 0

  assert_eq "${calls[*]}" \
    "context:demo ensure:/tmp/demo.plist bootstrap:/tmp/demo.plist:label.demo:0 success:任务已启用" \
    "execute enable uses shared job context"
}

test_execute_disable_uses_shared_context() {
  local calls=()

  resolve_job_execution_context() { calls+=("context:$1"); JOB_ACTION_LABEL="label.$1"; JOB_ACTION_PLIST_PATH="/tmp/$1.plist"; }
  launchctl_disable() { calls+=("disable:$1:$2"); }
  launchctl_bootout() { calls+=("bootout:$1:$2"); }
  success() { calls+=("success:$1"); }

  execute_disable demo 0

  assert_eq "${calls[*]}" \
    "context:demo disable:label.demo:0 bootout:label.demo:0 success:任务已禁用" \
    "execute disable uses shared job context"
}

main() {
  cd "$REPO_ROOT"
  test_execute_create_keeps_phase_order
  test_execute_delete_keeps_phase_order
  test_execute_enable_uses_shared_context
  test_execute_disable_uses_shared_context
  printf '\nJob scheduler guard passed: %d\n' "$PASS_COUNT"
}

main "$@"
