#!/bin/zsh
# filepath: tests/cli_dispatch_guard.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS_COUNT=0

pass() { printf '[PASS] %s\n' "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { printf '[FAIL] %s\n' "$1" >&2; exit 1; }
assert_eq() { [[ "$1" == "$2" ]] || { printf 'expected: %s\nactual:   %s\n' "$2" "$1" >&2; fail "$3"; }; pass "$3"; }
assert_contains() { [[ "$1" == *"$2"* ]] || { printf 'missing substring: %s\noutput: %s\n' "$2" "$1" >&2; fail "$3"; }; pass "$3"; }

error() { printf 'ERROR:%s\n' "$*" >&2; }
usage_error() { printf 'USAGE_ERROR:%s|%s\n' "$1" "$2"; return 1; }
command_error() { printf 'COMMAND_ERROR:%s|%s\n' "$1" "$2"; return 1; }
has_help_flag() { return 1; }
has_help_flag_before_separator() { return 1; }
reject_extra_args() { [[ $# -eq 1 ]] && return 0; shift; [[ $# -eq 0 ]] && return 0; return 1; }
print_setup_github_help() { printf 'HELP:setup-github\n'; }
print_release_help() { printf 'HELP:release\n'; }
print_release_publish_help() { printf 'HELP:release-publish\n'; }
print_release_verify_help() { printf 'HELP:release-verify\n'; }
print_job_help() { printf 'HELP:job\n'; }
print_job_create_help() { printf 'HELP:job-create\n'; }
print_job_list_help() { printf 'HELP:job-list\n'; }
print_job_status_help() { printf 'HELP:job-status\n'; }
print_job_enable_help() { printf 'HELP:job-enable\n'; }
print_job_disable_help() { printf 'HELP:job-disable\n'; }
print_job_delete_help() { printf 'HELP:job-delete\n'; }
validate_setup_git_args() { return 0; }
validate_setup_github_args() { return 0; }
validate_release_publish_args() { return 0; }
validate_release_verify_args() { return 0; }
validate_job_create_args() { return 0; }
validate_job_list_args() { return 0; }
validate_job_name_action_args() { return 0; }
normalize_release_tag() { printf 'v%s' "${1#v}"; }
infer_release_notes_file() { printf 'releases/%s-release-notes.md' "$1"; }

# shellcheck disable=SC1091
source "$REPO_ROOT/bin/lib/cli_runtime.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/bin/lib/cli_dispatch_release.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/bin/lib/cli_dispatch_setup.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/bin/lib/cli_dispatch_job.sh"

RUN_BASH_SCRIPT_PATH=""
typeset -ga RUN_BASH_SCRIPT_ARGS=()
run_bash_script() {
  RUN_BASH_SCRIPT_PATH="$1"
  shift
  RUN_BASH_SCRIPT_ARGS=("$@")
}

RUN_ZSH_SCRIPT_PATH=""
typeset -ga RUN_ZSH_SCRIPT_ARGS=()
run_zsh_script() {
  RUN_ZSH_SCRIPT_PATH="$1"
  shift
  RUN_ZSH_SCRIPT_ARGS=("$@")
}

test_setup_github_adds_defaults() {
  RUN_BASH_SCRIPT_ARGS=()
  handle_setup_github --force
  assert_eq "${RUN_BASH_SCRIPT_ARGS[*]}" "--domain github.com --type personal --force" "setup github forwards default domain and type"
}

test_build_release_forwarded_args_publish() {
  local args=()
  while IFS= read -r arg; do
    args+=("$arg")
  done < <(build_release_forwarded_args publish 0.3.0 --yes)

  assert_eq "${args[*]}" "--tag v0.3.0 --update-existing --yes --notes-file releases/v0.3.0-release-notes.md" "release publish builds default forwarded args"
}

test_handle_job_create_routes_scheduler() {
  handle_job create --job-name demo --script ./lint/lint_shell.sh --interval 5 --dry-run
  assert_eq "$RUN_ZSH_SCRIPT_PATH" "job/scheduler.sh" "job create routes to scheduler"
  assert_eq "${RUN_ZSH_SCRIPT_ARGS[*]}" "create --job-name demo --script ./lint/lint_shell.sh --interval 5 --dry-run" "job create preserves forwarded args"
}

main() {
  cd "$REPO_ROOT"
  test_setup_github_adds_defaults
  test_build_release_forwarded_args_publish
  test_handle_job_create_routes_scheduler
  printf '\nCLI dispatch guard passed: %d\n' "$PASS_COUNT"
}

main "$@"
