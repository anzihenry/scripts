#!/bin/zsh
# filepath: tools/vendor_zsh_kit.sh
# Offline, explicit vendoring. Never fetches or executes source package code.
set -euo pipefail
export LC_ALL=C
source "${0:A:h}/lib/artifact_runtime.sh"
usage() { print -u2 '用法: vendor_zsh_kit.sh --sync|--diff SOURCE DEST | --check DEST'; }
mode="${1:-}"; (( $# > 0 )) && shift
case "$mode:$#" in --check:1) ;; --sync:2|--diff:2) ;; *) usage; exit 2 ;; esac
# Manifest covers all payload files; reject symlinks and unexpected payload names.
hashes() (
 cd "$1" || return 1
 local item
 for item in **/*(DN.); do
  [[ "$item" != .zsh-kit-manifest ]] || continue
  [[ "$item" != *$'\n'* && "$item" != *$'\t'* ]] || return 1
  shasum -a 256 -- "$item" || return 1
 done
)
validate_tree() {
 local base="$1" item
 [[ -d "$base" && ! -L "$base" ]] || return 1
 for item in "$base"/**/*(DN); do
  [[ ! -L "$item" && ( -d "$item" || -f "$item" ) ]] || return 1
 done
 [[ -f "$base/VERSION" && -f "$base/LICENSE" && -f "$base/README.md" && -f "$base/lib/zsh-kit.sh" && -f "$base/tests/contract.sh" ]]
}
check() {
 validate_tree "$1" || { print -u2 '组件结构无效或含符号链接'; return 1; }
 [[ -f "$1/.zsh-kit-manifest" ]] || { print -u2 '缺少 vendor 清单'; return 1; }
 local expected actual version metadata
 version="$(cat "$1/VERSION")" || return 1
 [[ "$version" =~ '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' ]] || { print -u2 '组件版本必须为三段十进制版本'; return 1; }
 local -a header
 header=("${(@f)$(sed -n '1,6p' "$1/.zsh-kit-manifest")}")
 [[ ${#header} == 6 && "$header[1]" == format=1 && "$header[2]" == "version=$version" && "$header[3]" == source_url=?* && "$header[6]" == FILES ]] || { print -u2 '清单头或版本不一致'; return 1; }
 metadata="${header[4]#source_revision=}"
 [[ "$header[4]" == source_revision=* && ( "$metadata" == unversioned || ( ${#metadata} == 40 && "$metadata" != *[^0-9a-f]* ) ) ]] || return 1
 [[ "$header[5]" == source_dirty=false || "$header[5]" == source_dirty=true || "$header[5]" == source_dirty=unknown ]] || return 1
 expected="$(sed '1,/^FILES$/d' "$1/.zsh-kit-manifest")" || return 1
 actual="$(hashes "$1")" || return 1
 [[ -n "$expected" && "$actual" == "$expected" ]] || { print -u2 'vendor 文件与清单不一致；请先保存本地改动'; return 1; }
}
if [[ "$mode" == --check ]]; then check "$1"; print 'vendor 校验通过'; exit 0; fi
[[ -n "$1" && -n "$2" && "$2" != *$'\n'* && ! -L "$2" ]] || exit 2
source_dir="${1:A}"; destination="${2:A}"
validate_tree "$source_dir" || { print -u2 '源组件结构无效'; exit 1; }
[[ "$destination" != "$source_dir" && "$destination/" != "$source_dir/"* && "$source_dir/" != "$destination/"* ]] || { print -u2 '源与目标不能重叠'; exit 2; }
if [[ "$mode" == --diff && ( -e "$destination" || -L "$destination" ) ]]; then check "$destination"; fi
if [[ "$mode" == --diff ]]; then
 [[ -d "$destination" ]] || { print -u2 '目标尚未同步'; exit 1; }
 diff -ru -x .zsh-kit-manifest "$destination" "$source_dir"
 exit $?
fi
# Lock the canonical destination and recheck after acquiring it.
_artifact_lock "$destination"
if [[ "${ZSH_KIT_REQUIRE_NEW_DEST:-false}" == true && ( -e "$destination" || -L "$destination" ) ]]; then
 print -u2 '产物目标已存在，拒绝覆盖'; exit 2
fi
mkdir -p "${destination:h}"
_artifact_begin "$destination" check
work="$ARTIFACT_WORK"
cleanup() {
 local code=$?
 _artifact_recover "$work" "$destination" check || print -u2 "事务保留，下一次同步将重试恢复: $work"
 return "$code"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
if [[ "${ZSH_KIT_REQUIRE_NEW_DEST:-false}" == true && ( -e "$destination" || -L "$destination" ) ]]; then
 print -u2 '恢复后的目标已存在，拒绝覆盖'; exit 2
fi
[[ ! -e "$destination" && ! -L "$destination" ]] || check "$destination"
validate_tree "$source_dir"
mkdir "$work/package"
# Copy a closed set of distributable roots; never copy .git or local tooling secrets.
cp -R "$source_dir/lib" "$source_dir/tests" "$source_dir/VERSION" "$source_dir/LICENSE" "$source_dir/README.md" "$work/package/"
for metadata in API.txt CHANGELOG.md; do
 [[ ! -f "$source_dir/$metadata" ]] || cp "$source_dir/$metadata" "$work/package/"
done
revision=unversioned source_url=local dirty=unknown
if command -v git >/dev/null && git -C "$source_dir" rev-parse --show-toplevel >/dev/null 2>&1; then
 revision="$(git -C "$source_dir" rev-parse HEAD)"
 source_url="$(git -C "$source_dir" config --get remote.origin.url || print local)"
 dirty=false
 [[ -z "$(git -C "$source_dir" status --porcelain -- .)" ]] || dirty=true
 [[ -z "$(git -C "$source_dir" ls-files --others --ignored --exclude-standard -- .)" ]] || dirty=true
fi
source_url="${ZSH_KIT_SOURCE_URL-$source_url}"
[[ -n "$source_url" && "$source_url" != *$'\n'* && "$source_url" != *$'\r'* && "$source_url" != *$'\t'* && "$source_url" != *://*@* ]] || { print -u2 '来源 URL 无效或包含认证信息'; exit 2; }
{
 print -r -- 'format=1'
 print -r -- "version=$(cat "$source_dir/VERSION")"
 print -r -- "source_url=$source_url"
 print -r -- "source_revision=$revision"
 print -r -- "source_dirty=$dirty"
 print 'FILES'
 hashes "$work/package"
} > "$work/package/.zsh-kit-manifest"
check "$work/package"
# Verify the source did not change while the candidate was being copied.
[[ "$(hashes "$work/package")" == "$(hashes "$source_dir")" ]] || { print -u2 '源组件在复制期间发生变化或包含未分发文件'; exit 1; }
# Keep old payload until the replacement succeeds; rollback on a failed rename.
if [[ -d "$destination" ]]; then mv "$destination" "$work/previous"; fi
if ! mv "$work/package" "$destination"; then
 [[ ! -d "$work/previous" ]] || mv "$work/previous" "$destination"
 exit 1
fi
_artifact_recover "$work" "$destination" check
print -- "已同步 zsh-kit $(cat "$destination/VERSION") → $destination"
