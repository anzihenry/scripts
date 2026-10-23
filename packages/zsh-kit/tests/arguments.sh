#!/bin/zsh
# filepath: packages/zsh-kit/tests/arguments.sh
set -euo pipefail
ROOT="${0:A:h:h}"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/kit-arguments.XXXXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
source "$ROOT/lib/zsh-kit.sh"
# Any lock/command invocation during invalid argument handling is a failure.
sk_resource_lock_acquire() { touch "$SANDBOX/lock-attempt"; return 1; }
action() { touch "$SANDBOX/command-attempt"; }
bad_command() { local SK_DRY_RUN="$1"; sk_run_command action; }
bad_timed() { local SK_DRY_RUN=ture; sk_run_timed_command_or_fail key start ok fail detail action; }
bad_log() { local SK_LOG_MAX_BYTES="$1"; sk_append_log "$SANDBOX/new/log" data; }
check_bad() {
    local mode code
    for mode in direct conditional or_chain; do
        code=0
        case "$mode" in
          direct) set +e; "$@" > /dev/null 2>&1; code=$?; set -e ;;
          conditional) if "$@" >/dev/null 2>&1; then code=0; else code=$?; fi ;;
          or_chain) "$@" >/dev/null 2>&1 || code=$? ;;
        esac
        [[ "$code" == 2 ]] || { print -u2 "FAIL ($mode): $* returned $code"; exit 1; }
        [[ -z "$(ls -A "$SANDBOX")" ]] || { print -u2 "FAIL side effects: $*"; exit 1; }
    done
}
for flag in ture TRUE 1 ''; do
    check_bad sk_write_managed_file "$SANDBOX/new/config" content "$flag"
    check_bad sk_write_managed_block "$SANDBOX/new/config" section manager content "$flag"
    check_bad sk_write_managed_block "$SANDBOX/new/config" section manager content false 'managed by' "$flag"
    check_bad bad_command "$flag"
done
for mode in 888 12 u+r ''; do
    [[ -n "$mode" ]] || continue # empty mode deliberately means preserve/default
    check_bad sk_write_managed_file "$SANDBOX/new/config" content false "$mode"
done
for size in 0 -1 1073741825 10000000000000000000 ''; do check_bad bad_log "$size"; done
check_bad sk_with_resource_lock '' action
check_bad bad_timed
check_bad sk_write_managed_file '' content
check_bad sk_write_managed_block "$SANDBOX/new/config" '' manager content
check_bad sk_set_ini_values "$SANDBOX/new/config" section key value later $'bad\nvalue'
check_bad sk_set_ini_values "$SANDBOX/new/config" section 'bad=key' value
check_bad sk_append_log '' data
check_bad sk_start_capture ''
check_bad sk_start_capture "$SANDBOX/new/log" bad-mode
check_bad sk_commit_config_candidate '' candidate
check_bad sk_log
check_bad sk_time_start ''
check_bad sk_run_command ''
check_bad sk_run_stages first action later ''
print 'Argument contracts passed (direct/conditional/OR, no side effects)'
