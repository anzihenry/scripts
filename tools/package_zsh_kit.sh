#!/bin/zsh
# filepath: tools/package_zsh_kit.sh
# Produce an offline directory payload from a clean, tracked package revision.
set -euo pipefail
TOOLS="${0:A:h}"
mode="${1:-}"
case "$mode:$#" in --check:2|--build:3) ;; *) print -u2 '用法: package_zsh_kit.sh --check SOURCE | --build SOURCE NEW_DEST'; exit 2 ;; esac
source_dir="${2:A}"
[[ -d "$source_dir" && -f "$source_dir/VERSION" && -f "$source_dir/API.txt" && -f "$source_dir/CHANGELOG.md" ]] || exit 2
git -C "$source_dir" rev-parse --show-toplevel >/dev/null || exit 1
revision="$(git -C "$source_dir" rev-parse HEAD)"
[[ -n "$(git -C "$source_dir" ls-files -- VERSION)" ]] || { print -u2 '组件必须已纳入 Git'; exit 1; }
[[ -z "$(git -C "$source_dir" status --porcelain --untracked-files=all -- .)" ]] || { print -u2 '组件有未提交改动，拒绝生成发布产物'; exit 1; }
for payload in "$source_dir"/lib/**/*(DN) "$source_dir"/tests/**/*(DN) "$source_dir"/VERSION "$source_dir"/README.md "$source_dir"/LICENSE "$source_dir"/API.txt "$source_dir"/CHANGELOG.md; do
 [[ ! -L "$payload" ]] || { print -u2 '发布包不能含符号链接'; exit 1; }
 [[ ! -d "$payload" ]] || continue
 [[ -f "$payload" ]] || exit 1
 git -C "$source_dir" ls-files --error-unmatch -- "${payload#$source_dir/}" >/dev/null 2>&1 || { print -u2 "未跟踪的发布文件: $payload"; exit 1; }
done
version="$(cat "$source_dir/VERSION")"
[[ "$version" =~ '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' ]] || exit 2
grep -Eq "^## ${version//./\.}([[:space:]]|$)" "$source_dir/CHANGELOG.md" || { print -u2 '缺少对应版本的变更记录'; exit 1; }
# Static inspection only: do not execute source package code while packaging.
actual="$(sed -nE 's/^(sk_[a-z_]+)\(\).*/\1/p' "$source_dir"/lib/*.sh | LC_ALL=C sort)"
[[ "$actual" == "$(cat "$source_dir/API.txt")" ]] || { print -u2 '公开接口与清单不一致'; exit 1; }
if [[ "$mode" == --check ]]; then print -- "发布前静态检查通过: zsh-kit $version @ $revision"; exit 0; fi
[[ -n "$3" && ! -e "$3" && ! -L "$3" ]] || { print -u2 '产物目标必须不存在'; exit 2; }
destination="${3:A}"
# The sync tool serializes creation, checks payload hashes and records source provenance.
ZSH_KIT_REQUIRE_NEW_DEST=true /bin/zsh "$TOOLS/vendor_zsh_kit.sh" --sync "$source_dir" "$destination"
if [[ "$(git -C "$source_dir" rev-parse HEAD)" != "$revision" || -n "$(git -C "$source_dir" status --porcelain --untracked-files=all -- .)" ]]; then
 print -u2 "构建期间源版本发生变化，产物不可发布，请检查: $destination"; exit 1
fi
grep -Fqx "source_revision=$revision" "$destination/.zsh-kit-manifest"
grep -Fqx 'source_dirty=false' "$destination/.zsh-kit-manifest"
print -- "离线产物已生成；尚未发布: $destination"
