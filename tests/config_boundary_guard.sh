#!/bin/zsh
# filepath: tests/config_boundary_guard.sh
set -euo pipefail
ROOT="${0:A:h:h}"
source "$ROOT/packages/zsh-kit/lib/config_writer.sh"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/config-boundary.XXXXXXXX")"
trap 'chmod -R u+rwX "$SANDBOX"; rm -rf "$SANDBOX"' EXIT
fail() { print -u2 -- "FAIL: $*"; exit 1; }
mkdir "$SANDBOX/real directory"
ln -s "$SANDBOX/real directory" "$SANDBOX/parent link"
target="$SANDBOX/parent link/配置 file"
sk_write_managed_file "$target" 'export KEEP=1' false 640
ln -s "$target" "$SANDBOX/alias"
sk_write_managed_block "$SANDBOX/alias" section test 'export CHANGED=1' false 'managed by' true
[[ -L "$SANDBOX/alias" && "$(stat -f '%Lp' "${target:A}")" == 640 ]] || fail metadata
cp "$target" "$SANDBOX/before"
identity="$(stat -f '%i:%m:%Lp' "${target:A}")"
sk_write_managed_block "$SANDBOX/alias" section test 'export CHANGED=1' false 'managed by' true
[[ "$identity" == "$(stat -f '%i:%m:%Lp' "${target:A}")" ]] || fail idempotence
if sk_write_managed_block "$SANDBOX/alias" section test 'if broken' false 'managed by' true 2>/dev/null; then fail syntax; fi
cmp -s "$target" "$SANDBOX/before" || fail '语法校验失败改动原文件'
ln -s "$SANDBOX/missing" "$SANDBOX/dangling"
if sk_write_managed_file "$SANDBOX/dangling" content 2>/dev/null; then fail dangling; fi
[[ ! -e "$SANDBOX/missing" && -L "$SANDBOX/dangling" ]] || fail '失效链接被写入'
if (( EUID != 0 )); then
    chmod 500 "$SANDBOX/real directory"
    code=0
    sk_write_managed_file "$target" changed 2>/dev/null || code=$?
    chmod 700 "$SANDBOX/real directory"
    [[ "$code" != 0 ]] || fail readonly
    cmp -s "$target" "$SANDBOX/before" || fail '只读目录失败改动原文件'
else
    print 'SKIP: root 无法证明普通用户目录权限拒绝'
fi
print 'PASS: linked paths, metadata, idempotence, validation and unwritable parent'

# 模拟 Formula 的运行布局：不提供 tools/release，用户入口仍可加载。
mkdir "$SANDBOX/installed"
cp -R "$ROOT/bin" "$ROOT/lib" "$ROOT/packages" "$ROOT/setup" "$ROOT/maintain" "$ROOT/lint" "$ROOT/VERSION" "$SANDBOX/installed/"
output="$(/bin/zsh "$SANDBOX/installed/bin/macos-scripts" --help)"
[[ "$output" == *setup* && "$output" != *'release publish'* && "$output" != *'release verify'* ]] || fail public-help
if /bin/zsh "$SANDBOX/installed/bin/macos-scripts" release > "$SANDBOX/release.out" 2>&1; then fail public-release; fi
grep -q '未知命令: release' "$SANDBOX/release.out"
print 'PASS: installed public CLI has no dependency on repository release tooling'
