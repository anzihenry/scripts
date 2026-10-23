#!/bin/zsh
# filepath: packages/zsh-kit/tests/contract.sh
set -euo pipefail
ROOT="${0:A:h:h}"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/zsh-kit-contract.XXXXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
mkdir "$HOME"
fail() { print -u2 -- "FAIL: $*"; exit 1; }
pass() { print -- "PASS: $*"; }
# Loading leaves options, traps, output and resources unchanged.
/bin/zsh -c '
 set -eu; trap ":" TERM
 before_options="$(setopt)"; before_traps="$(trap)"
 source "$1/lib/zsh-kit.sh"
 sk_time_start running
 source "$1/lib/zsh-kit.sh"
 [[ "$(setopt)" == "$before_options" && "$(trap)" == "$before_traps" ]] || exit 1
 [[ -n "${SK_TIMERS[running]:-}" ]] || exit 1
 sk_time_end running >/dev/null 2>&1
' zsh "$ROOT" > "$SANDBOX/source.out" || fail loading
[[ ! -s "$SANDBOX/source.out" && -z "$(ls -A "$HOME")" ]] || fail 'source side effects'
# Reverse module load order must also work.
/bin/zsh -c 'set -eu; for f in "$1"/lib/*.sh(On); do source "$f"; done; sk_info hello' zsh "$ROOT" > "$SANDBOX/out" 2> "$SANDBOX/err"
[[ ! -s "$SANDBOX/out" && -s "$SANDBOX/err" ]] || fail 'diagnostic stream'
pass 'repeated/order-independent loading preserves caller state'
source "$ROOT/lib/zsh-kit.sh"
bad_action() { return 7; }
for invocation in direct conditional or_chain; do
 case "$invocation" in
  direct) set +e; sk_run_command bad_action; result=$?; set -e ;;
  conditional) if sk_run_command bad_action; then result=0; else result=$?; fi ;;
  or_chain) result=0; sk_run_command bad_action || result=$? ;;
 esac
 [[ "$result" == 7 ]] || fail "$invocation error propagation"
done
result=0; sk_run_timed_command_or_fail test start done failed detail bad_action 2>/dev/null || result=$?
[[ "$result" == 7 ]] || fail timed-status
later() { touch "$SANDBOX/later"; }
result=0; sk_run_stages fail bad_action later later 2>/dev/null || result=$?
[[ "$result" == 7 && ! -e "$SANDBOX/later" ]] || fail stages
SK_DRY_RUN=true sk_run_command touch "$SANDBOX/dry" >/dev/null
[[ ! -e "$SANDBOX/dry" ]] || fail dry-run
pass 'direct/conditional/OR errors, stages and dry-run'
sk_write_managed_file "$SANDBOX/config" original
before="$(stat -f '%i:%m:%Lp' "$SANDBOX/config")"
sk_write_managed_file "$SANDBOX/config" original
[[ "$before" == "$(stat -f '%i:%m:%Lp' "$SANDBOX/config")" ]] || fail idempotence
ln -s "$SANDBOX/config" "$SANDBOX/link"
sk_write_managed_block "$SANDBOX/link" section test content
[[ -L "$SANDBOX/link" ]] || fail symlink
cp "$SANDBOX/config" "$SANDBOX/before"
( _sk_commit_config_candidate() { return 9; }; sk_write_managed_file "$SANDBOX/config" changed ) && fail fault-status
cmp -s "$SANDBOX/config" "$SANDBOX/before" || fail atomic-fault
( _sk_update_ini_candidate() { return 9; }; sk_set_ini_values "$SANDBOX/config" section key value ) && fail ini-fault
cmp -s "$SANDBOX/config" "$SANDBOX/before" || fail ini-atomic
[[ -z "$(print -l -- "$SANDBOX"/*.write.*(N) "$SANDBOX"/*.ini-batch.*(N))" ]] || fail temp-cleanup
result=0; sk_write_managed_file || result=$?; [[ "$result" == 2 ]] || fail argument-status
pass 'atomic file/INI failure, symlinks and unchanged writes'
# Different application HOME values must still coordinate on the same canonical path.
(
 sk_resource_lock_acquire "$SANDBOX/config"
 HOME="$SANDBOX/other-project" SK_LOCK_TIMEOUT=0 /bin/zsh -c 'source "$1/lib/zsh-kit.sh"; sk_resource_lock_acquire "$2"' zsh "$ROOT" "$SANDBOX/link" 2>/dev/null && fail competing-project
 sk_resource_lock_acquire "$SANDBOX/link"
 source "$ROOT/lib/resource_lock.sh"
 [[ ${#SK_RESOURCE_LOCKS} == 1 ]] || fail reload-lock
 sk_resource_locks_release_owned
)
SK_LOCK_TIMEOUT=0 sk_with_resource_lock "$SANDBOX/config" true
pass 'shared cross-project lock, reload/reentry and release'
SK_LOG_MAX_BYTES=8 SK_LOG_BACKUPS=2 sk_append_log "$SANDBOX/run.log" 123456789012345678901234567890
[[ $(stat -f '%z' "$SANDBOX/run.log") -le 8 && ! -e "$SANDBOX/run.log.3" ]] || fail rotation
/bin/zsh -c 'source "$1/lib/zsh-kit.sh"; sk_start_capture "$2"; print final; exit 7' zsh "$ROOT" "$SANDBOX/capture.log" > "$SANDBOX/capture.out" && fail capture-status || result=$?
[[ "$result" == 7 && "$(<"$SANDBOX/capture.log")" == final ]] || fail capture
pass 'bounded logging and capture preserves business exit'
print 'zsh-kit contract passed'
