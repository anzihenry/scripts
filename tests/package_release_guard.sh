#!/bin/zsh
# filepath: tests/package_release_guard.sh
set -euo pipefail
ROOT="${0:A:h:h}"
sandbox="$(mktemp -d "${TMPDIR:-/tmp}/package-release.XXXXXXXX")"
trap 'rm -rf "$sandbox"' EXIT
export HOME="$sandbox/home" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME" "$sandbox/repo/packages"
cp -R "$ROOT/packages/zsh-kit" "$sandbox/repo/packages/zsh-kit"
repo="$sandbox/repo"; source_dir="$repo/packages/zsh-kit"
git -C "$repo" init -q
git -C "$repo" add .
git -C "$repo" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm baseline
git -C "$repo" remote add origin https://example.invalid/zsh-kit
builder="$ROOT/tools/package_zsh_kit.sh"; vendor_tool="$ROOT/tools/vendor_zsh_kit.sh"
/bin/zsh "$builder" --check "$source_dir"
/bin/zsh "$builder" --build "$source_dir" "$sandbox/output-one" >/dev/null
/bin/zsh "$builder" --build "$source_dir" "$sandbox/output-two" >/dev/null
cmp -s "$sandbox/output-one/.zsh-kit-manifest" "$sandbox/output-two/.zsh-kit-manifest"
/bin/zsh "$builder" --build "$source_dir" "$sandbox/output-one" 2>/dev/null && exit 1
/bin/zsh "$sandbox/output-one/tests/contract.sh" >/dev/null
# Headers are validated independently of unchanged payload hashes.
for mutation in version format revision dirty; do
 cp "$sandbox/output-one/.zsh-kit-manifest" "$sandbox/original"
 case "$mutation" in
  version) sed 's/^version=.*/version=9.9.9/' "$sandbox/original" ;;
  format) sed 's/^format=.*/format=99/' "$sandbox/original" ;;
  revision) sed 's/^source_revision=.*/source_revision=not-a-commit/' "$sandbox/original" ;;
  dirty) sed 's/^source_dirty=.*/source_dirty=maybe/' "$sandbox/original" ;;
 esac > "$sandbox/output-one/.zsh-kit-manifest"
 /bin/zsh "$vendor_tool" --check "$sandbox/output-one" >/dev/null 2>&1 && exit 1
 mv "$sandbox/original" "$sandbox/output-one/.zsh-kit-manifest"
done
print '*.ignored' > "$repo/.gitignore"
git -C "$repo" add .gitignore
git -C "$repo" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm ignore-fixture
print ignored > "$source_dir/lib/untracked.ignored"
/bin/zsh "$builder" --check "$source_dir" >/dev/null 2>&1 && exit 1
rm "$source_dir/lib/untracked.ignored"
print dirty >> "$source_dir/README.md"
/bin/zsh "$builder" --build "$source_dir" "$sandbox/dirty-output" >/dev/null 2>&1 && exit 1
[[ ! -e "$sandbox/dirty-output" ]]
git -C "$repo" checkout -- packages/zsh-kit/README.md
print '9.9.9' > "$source_dir/VERSION"
git -C "$repo" add .
git -C "$repo" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm missing-changelog
/bin/zsh "$builder" --check "$source_dir" >/dev/null 2>&1 && exit 1
/bin/zsh "$vendor_tool" --check "$sandbox/output-two" >/dev/null
print 'Package release guard passed: clean source, deterministic payload, metadata rejection, no overwrite'
