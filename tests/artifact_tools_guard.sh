#!/bin/zsh
# filepath: tests/artifact_tools_guard.sh
set -euo pipefail
setopt no_bg_nice
ROOT="${0:A:h:h}"
main() {
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/artifact-tools.XXXXXXXX")"
SANDBOX="${SANDBOX:A}"
cleanup() {
    if [[ -n "${first:-}" ]]; then
        : > "$SANDBOX/ready.release"
        wait "$first" 2>/dev/null || true
    fi
    rm -rf "$SANDBOX"
}
trap cleanup EXIT
fail() { print -u2 "FAIL: $*"; exit 1; }
tool="$ROOT/tools/vendor_zsh_kit.sh"
cp -R "$ROOT/packages/zsh-kit" "$SANDBOX/source"
source_dir="$SANDBOX/source"; destination="$SANDBOX/vendor/kit"
mkdir "$SANDBOX/shims"
ln -s "$source_dir" "$SANDBOX/alias"
/bin/zsh "$tool" --sync "$source_dir" "$SANDBOX/alias/nested" 2>/dev/null && fail overlap
[[ ! -e "$source_dir/nested" ]] || fail overlap-write
/bin/zsh "$tool" --sync "$source_dir" "$destination" >/dev/null
cat > "$SANDBOX/shims/mv" <<'SHIM'
#!/bin/zsh
if [[ "${FAULT_KIND:-}" != '' && "$1" == "$TEST_DESTINATION" && "${2:t}" == previous ]]; then
 /bin/mv "$@" || exit 1
 case "$FAULT_KIND" in
  term) kill -TERM "$PPID" ;;
  kill) kill -KILL "$PPID" ;;
  obstruct) mkdir "$TEST_DESTINATION"; exit 9 ;;
 esac
 exit 0
fi
exec /bin/mv "$@"
SHIM
cat > "$SANDBOX/shims/cp" <<'SHIM'
#!/bin/zsh
if [[ "${FAIL_COPY:-false}" == true ]]; then exit 9; fi
if [[ -n "${HOLD_MARKER:-}" ]]; then
 : > "$HOLD_MARKER"
 while [[ ! -e "$HOLD_MARKER.release" ]]; do /bin/sleep 0.02; done
fi
exec /bin/cp "$@"
SHIM
chmod +x "$SANDBOX/shims/"*
export TEST_DESTINATION="$destination"
for fault in term kill obstruct; do
 code=0
 FAULT_KIND="$fault" PATH="$SANDBOX/shims:$PATH" /bin/zsh "$tool" --sync "$source_dir" "$destination" > "$SANDBOX/fault.log" 2>&1 || code=$?
 [[ "$code" != 0 ]] || fail "$fault status"
 if [[ "$fault" == term ]]; then /bin/zsh "$tool" --check "$destination" >/dev/null; fi
 if [[ "$fault" == obstruct ]]; then
  backups=("${destination:h}"/.zsh-kit-transaction-*/previous(N/))
  (( ${#backups} == 1 )) || fail backup-lost
  /bin/zsh "$tool" --check "$backups[1]" >/dev/null
  rmdir "$destination" # remove only the empty obstruction created by this test
 fi
 /bin/zsh "$tool" --sync "$source_dir" "$destination" >/dev/null
 /bin/zsh "$tool" --check "$destination" >/dev/null
done
# Hold a real sync inside cp, then contend through a symlink alias of its parent.
HOLD_MARKER="$SANDBOX/ready" PATH="$SANDBOX/shims:$PATH" /bin/zsh "$tool" --sync "$source_dir" "$destination" > "$SANDBOX/first.log" 2>&1 &
first=$!
for ((i=0; i<200; i++)); do [[ ! -e "$SANDBOX/ready" ]] || break; sleep 0.02; done
[[ -e "$SANDBOX/ready" ]] || fail readiness
ln -s "${destination:h}" "$SANDBOX/vendor-alias"
ZSH_KIT_TOOL_LOCK_TIMEOUT=0 /bin/zsh "$tool" --sync "$source_dir" "$SANDBOX/vendor-alias/kit" 2>/dev/null && fail concurrency
: > "$SANDBOX/ready.release"
wait "$first"
first=''
/bin/zsh "$tool" --check "$destination" >/dev/null
FAIL_COPY=true PATH="$SANDBOX/shims:$PATH" /bin/zsh "$ROOT/tools/create_zsh_project.sh" --name failed-project "$SANDBOX/generated" >/dev/null 2>&1 && fail generation-fault
[[ ! -e "$SANDBOX/generated" ]] || fail partial-project
/bin/zsh "$ROOT/tools/create_zsh_project.sh" --name good-project "$SANDBOX/generated" >/dev/null
[[ -f "$SANDBOX/generated/project.conf" ]] || fail generation-retry
print 'Artifact tools guard passed: aliases, contention, TERM/KILL, retained backup, generation retry'

}
main "$@"
