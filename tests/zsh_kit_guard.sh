#!/bin/zsh
# filepath: tests/zsh_kit_guard.sh
set -euo pipefail
ROOT="${0:A:h:h}"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/kit distribution.XXXXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
fail() { print -u2 -- "FAIL: $*"; exit 1; }
cp -R "$ROOT/packages/zsh-kit" "$SANDBOX/independent kit"
/bin/zsh "$SANDBOX/independent kit/tests/contract.sh"
tool="$ROOT/tools/vendor_zsh_kit.sh"
/bin/zsh "$tool" --sync "$SANDBOX/independent kit" "$SANDBOX/project/vendor/zsh-kit"
/bin/zsh "$tool" --check "$SANDBOX/project/vendor/zsh-kit"
/bin/zsh "$tool" --diff "$SANDBOX/independent kit" "$SANDBOX/project/vendor/zsh-kit"
cp "$SANDBOX/project/vendor/zsh-kit/.zsh-kit-manifest" "$SANDBOX/before"
/bin/zsh "$tool" --sync "$SANDBOX/independent kit" "$SANDBOX/project/vendor/zsh-kit"
cmp -s "$SANDBOX/before" "$SANDBOX/project/vendor/zsh-kit/.zsh-kit-manifest" || fail reproducibility
print tamper >> "$SANDBOX/project/vendor/zsh-kit/lib/console.sh"
/bin/zsh "$tool" --check "$SANDBOX/project/vendor/zsh-kit" 2>/dev/null && fail tamper-check
/bin/zsh "$tool" --sync "$SANDBOX/independent kit" "$SANDBOX/project/vendor/zsh-kit" 2>/dev/null && fail tamper-overwrite
mkdir "$SANDBOX/unowned"
/bin/zsh "$tool" --sync "$SANDBOX/independent kit" "$SANDBOX/unowned" 2>/dev/null && fail unowned-overwrite
ln -s /tmp "$SANDBOX/independent kit/lib/unsafe"
/bin/zsh "$tool" --sync "$SANDBOX/independent kit" "$SANDBOX/unsafe" 2>/dev/null && fail symlink-copy
print 'zsh-kit distribution guard passed'
