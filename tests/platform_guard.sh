#!/bin/zsh
# filepath: tests/platform_guard.sh
set -euo pipefail
ROOT="${0:A:h:h}"
sandbox="$(mktemp -d "${TMPDIR:-/tmp}/platform-guard.XXXXXXXX")"
trap 'rm -rf "$sandbox"' EXIT
cat > "$sandbox/sw_vers" <<'SHIM'
#!/bin/zsh
case "$1" in -productVersion) print "${FAKE_OS:-14.7}" ;; -buildVersion) print test-build ;; *) exit 1 ;; esac
SHIM
cat > "$sandbox/uname" <<'SHIM'
#!/bin/zsh
print "${FAKE_ARCH:-arm64}"
SHIM
chmod +x "$sandbox/sw_vers" "$sandbox/uname"
PATH="$sandbox:$PATH" TEST_EXPECT_OS_MAJOR=14 TEST_EXPECT_ARCH=arm64 zsh "$ROOT/tools/platform_identity.sh" >/dev/null
PATH="$sandbox:$PATH" FAKE_ARCH=x86_64 TEST_EXPECT_OS_MAJOR=14 TEST_EXPECT_ARCH=x86_64 zsh "$ROOT/tools/platform_identity.sh" >/dev/null
for kind in os arch minimum invalid; do
 code=0
 case "$kind" in
  os) PATH="$sandbox:$PATH" TEST_EXPECT_OS_MAJOR=15 zsh "$ROOT/tools/platform_identity.sh" >/dev/null 2>&1 || code=$? ;;
  arch) PATH="$sandbox:$PATH" TEST_EXPECT_ARCH=x86_64 zsh "$ROOT/tools/platform_identity.sh" >/dev/null 2>&1 || code=$? ;;
  minimum) PATH="$sandbox:$PATH" FAKE_OS=13.6 zsh "$ROOT/tools/platform_identity.sh" >/dev/null 2>&1 || code=$? ;;
  invalid) TEST_EXPECT_OS_MAJOR=bad zsh "$ROOT/tools/platform_identity.sh" >/dev/null 2>&1 || code=$? ;;
 esac
 [[ "$code" != 0 ]]
done
code=0
PATH="$sandbox:$PATH" TEST_EXPECT_ARCH=x86_64 /bin/zsh "$ROOT/tests/run_all.sh" --report "$sandbox/report" >/dev/null 2>&1 || code=$?
[[ "$code" == 1 && -f "$sandbox/report/platform.log" && ! -e "$sandbox/report/bootstrap-sync.log" ]]
[[ "$(cat "$sandbox/report/summary.txt")" == *exit_code=1* ]]
code=0
/bin/zsh "$ROOT/tests/run_all.sh" --report "$sandbox/report" >/dev/null 2>&1 || code=$?
[[ "$code" == 2 ]]
print 'Platform expectation guard passed (simulated identities only)'
