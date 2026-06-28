#!/bin/zsh
# filepath: tests/job_runtime_guard.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS_COUNT=0

pass() { printf '[PASS] %s\n' "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { printf '[FAIL] %s\n' "$1" >&2; exit 1; }
assert_eq() { [[ "$1" == "$2" ]] || { printf 'expected: %s\nactual:   %s\n' "$2" "$1" >&2; fail "$3"; }; pass "$3"; }
assert_contains() { [[ "$1" == *"$2"* ]] || { printf 'missing substring: %s\noutput: %s\n' "$2" "$1" >&2; fail "$3"; }; pass "$3"; }

info() { printf 'INFO:%s\n' "$*"; }
warning() { printf 'WARN:%s\n' "$*"; }
error() { printf 'ERROR:%s\n' "$*" >&2; }
success() { printf 'SUCCESS:%s\n' "$*"; }
__color_format_duration() { printf '%ss' "$1"; }
print_usage() { printf 'USAGE:job scheduler\n'; }
require_command() { printf 'REQ:%s\n' "$1"; }

# shellcheck disable=SC1091
source "$REPO_ROOT/job/lib/job_runtime.sh"

test_initialize_scheduler_context() {
  initialize_scheduler_context create --job-name demo --dry-run
  assert_eq "$ACTION" "create" "initialize scheduler context captures action"
  assert_eq "${SCHEDULER_ARGS[*]}" "--job-name demo --dry-run" "initialize scheduler context stores remaining args"
}

test_run_scheduler_entry_help() {
  ACTION="--help"
  SCHEDULER_ARGS=()
  local output=""
  output="$(run_scheduler_entry)"
  assert_contains "$output" "USAGE:job scheduler" "run scheduler entry prints help for help action"
}

test_run_scheduler_entry_dispatches() {
  local calls=()
  ACTION="create"
  SCHEDULER_ARGS=(--job-name demo --dry-run)
  init_scheduler_args() { calls+=("init"); }
  parse_scheduler_args() { calls+=("parse:$*"); }
  dispatch_scheduler_action() { calls+=("dispatch"); }
  require_command() { calls+=("require:$1"); }

  run_scheduler_entry
  assert_eq "${calls[*]}" "require:launchctl require:plutil init parse:--job-name demo --dry-run dispatch" "run scheduler entry performs prerequisite and dispatch order"
}

main() {
  cd "$REPO_ROOT"
  test_initialize_scheduler_context
  test_run_scheduler_entry_help
  test_run_scheduler_entry_dispatches
  printf '\nJob runtime guard passed: %d\n' "$PASS_COUNT"
}

main "$@"
