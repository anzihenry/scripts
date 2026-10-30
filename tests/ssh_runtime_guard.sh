#!/bin/zsh
# filepath: tests/ssh_runtime_guard.sh
set -euo pipefail
ROOT="${0:A:h:h}"
source "$ROOT/setup/lib/ssh_runtime.sh"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/ssh-runtime.XXXXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
log_info() { print -r -- "$*"; }
log_success() { print -r -- "$*"; }
log_error() { print -ru2 -- "$*"; }
ssh() {
    print -rl -- "$@" > "$SANDBOX/args"
    print -r -- "$RESPONSE"
    return "$SSH_CODE"
}
check() {
    local expected="$1" actual=0
    test_ssh_connection example-work > "$SANDBOX/out" 2>&1 || actual=$?
    [[ "$actual" == "$expected" ]] || { cat "$SANDBOX/out"; exit 1; }
    grep -Fxq StrictHostKeyChecking=yes "$SANDBOX/args"
    grep -Fxq BatchMode=yes "$SANDBOX/args"
    grep -Fxq git@example-work "$SANDBOX/args"
}
SSH_CODE=1 RESPONSE="Hi user! You've successfully authenticated, but GitHub does not provide shell access."
check 0
SSH_CODE=0 RESPONSE='Welcome to GitLab, @user!'
check 0
SSH_CODE=1 RESPONSE='Welcome to GitLab, @user!'
check 0
SSH_CODE=0 RESPONSE='Custom forge authenticated'
check 0
SSH_CODE=1 RESPONSE='Unknown server response'
check 1
SSH_CODE=255 RESPONSE='Permission denied (publickey).'
check 255
grep -q 'ssh-agent' "$SANDBOX/out"
SSH_CODE=255 RESPONSE='Host key verification failed.'
check 255
grep -q '核对服务端指纹' "$SANDBOX/out"
SSH_CODE=255 RESPONSE='REMOTE HOST IDENTIFICATION HAS CHANGED'
check 255
grep -q '不要直接删除' "$SANDBOX/out"
SSH_CODE=255 RESPONSE='successfully authenticated then transport failed'
check 255
print 'PASS: SSH provider responses, original failure status and strict host trust'
