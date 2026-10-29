#!/bin/zsh
# filepath: tests/homebrew_recovery_guard.sh
set -euo pipefail
unsetopt BG_NICE
ROOT="${0:A:h:h}"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/homebrew-recovery.XXXXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
fail() { print -u2 -- "FAIL: $*"; exit 1; }
cat > "$SANDBOX/worker.sh" <<'WORKER'
#!/bin/zsh
set -euo pipefail
source "$1/lib/colors.sh"
source "$1/lib/utils.sh"
source "$1/lib/config_writer.sh"
source "$1/setup/lib/homebrew_config.sh"
TEST_ROOT="$2" MODE="$3"
export HOME="$TEST_ROOT/home" MACOS_SCRIPTS_CONFIG_DIR="$TEST_ROOT/state"
brew() { print -r -- "$TEST_ROOT/brew"; }
homebrew_configuration_current() {
    [[ "$MODE" == recover ]] || return 1
    [[ "$(cat "$HOME/.zshrc")" == 'export ORIGINAL=1' ]] || return 1
    return 0
}
pause_transaction() {
    zmodload zsh/system
    print -r -- "$sysparams[pid]" > "$TEST_ROOT/ready"
    while true; do sleep 0.1; done
}
configure_homebrew_shellenv() {
    write_managed_block "$HOME/.zshrc" crash test 'export CHANGED=1' || return 1
    [[ "$MODE" != unrecorded ]] || pause_transaction
}
configure_homebrew_mirror_exports() { pause_transaction; }
run_homebrew_config_transaction brew
WORKER
for scenario in known edited corrupt unrecorded; do
    work="$SANDBOX/$scenario"
    mkdir -p "$work/home" "$work/brew"
    git -C "$work/brew" init -q
    print 'export ORIGINAL=1' > "$work/home/.zshrc"
    /bin/zsh "$SANDBOX/worker.sh" "$ROOT" "$work" "$scenario" > "$work/start.log" 2>&1 &
    worker=$!
    for index in {1..100}; do [[ ! -f "$work/ready" ]] || break; sleep 0.05; done
    [[ -f "$work/ready" ]] || { kill "$worker" 2>/dev/null || true; fail '事务未就绪'; }
    kill -KILL "$(cat "$work/ready")"
    wait "$worker" 2>/dev/null || true
    journals=("$work/state/backups"/homebrew-config.*(N/))
    [[ ${#journals} == 1 && "$(cat "$journals[1]/state")" == active ]] || fail journal
    case "$scenario" in
        edited) print '# user changed after crash' >> "$work/home/.zshrc" ;;
        corrupt) print corrupt >> "$journals[1]/1" ;;
    esac
    cp "$work/home/.zshrc" "$work/before-recovery"
    code=0
    /bin/zsh "$SANDBOX/worker.sh" "$ROOT" "$work" recover > "$work/recovery.log" 2>&1 || code=$?
    if [[ "$scenario" == known ]]; then
        [[ "$code" == 0 && "$(cat "$work/home/.zshrc")" == 'export ORIGINAL=1' && "$(cat "$journals[1]/state")" == rolled-back ]] || fail recovery
    else
        [[ "$code" != 0 && -f "$journals[1]/1" ]] || fail '异常恢复必须拒绝并保留备份'
        cmp -s "$work/home/.zshrc" "$work/before-recovery" || fail '异常恢复覆盖用户文件'
    fi
    print -- "PASS: $scenario"
done
