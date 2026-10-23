#!/bin/zsh
# filepath: tools/create_zsh_project.sh
set -euo pipefail
ROOT="${0:A:h:h}"
source "$ROOT/tools/lib/artifact_runtime.sh"
name='' description='A macOS Zsh CLI' repository=''
while (( $# )); do
 case "$1" in
  --name|--description|--repository)
   (( $# >= 2 )) || { print -u2 "缺少 $1 参数值"; exit 2; }
   case "$1" in --name) name="$2" ;; --description) description="$2" ;; --repository) repository="$2" ;; esac
   shift 2 ;;
  --) shift; break ;;
  -*) print -u2 "未知选项: $1"; exit 2 ;;
  *) break ;;
 esac
done
(( $# == 1 )) || { print -u2 '用法: create_zsh_project.sh --name NAME [--description TEXT] [--repository URL] DEST'; exit 2; }
[[ -n "$name" && "$name" != *[^a-z0-9-]* && "$name" == [a-z]* && "$name" != *- && ${#name} -le 64 ]] || { print -u2 '名称必须是小写字母开头、字母或数字结尾的 kebab-case（最多64字符）'; exit 2; }
[[ -n "$1" && "$1" != *$'\n'* && ! -L "$1" ]] || exit 2
destination="${1:A}"
_artifact_lock "$destination"
[[ ! -e "$destination" && ! -L "$destination" ]] || { print -u2 '目标已存在，拒绝覆盖'; exit 1; }
mkdir -p "${destination:h}"
_artifact_begin "$destination" false
work="$ARTIFACT_WORK"
trap '_artifact_recover "$work" "$destination" false' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
cp -R "$ROOT/templates/zsh-cli" "$work/project"
mv "$work/project/bin/cli" "$work/project/bin/$name"
mkdir "$work/project/scripts"
cp "$ROOT/tools/vendor_zsh_kit.sh" "$work/project/scripts/"
cp -R "$ROOT/tools/lib" "$work/project/scripts/lib"
cp "$ROOT/LICENSE" "$work/project/LICENSE"
/bin/zsh "$ROOT/tools/vendor_zsh_kit.sh" --sync "$ROOT/packages/zsh-kit" "$work/project/vendor/zsh-kit"
prefix="${(U)name//-/_}"
{
 print '# Generated project metadata; trusted shell configuration.'
 printf 'APP_ID=%q\nAPP_COMMAND=%q\nAPP_DESCRIPTION=%q\nAPP_REPOSITORY=%q\nAPP_ENV_PREFIX=%q\n' "$name" "$name" "$description" "$repository" "$prefix"
 print 'APP_VERSION=0.1.0'
 print 'APP_MIN_MACOS=14'
 printf 'APP_KIT_VERSION=%q\n' "$(cat "$ROOT/packages/zsh-kit/VERSION")"
 print 'APP_DEFAULT_LOG_DIR="$HOME/Library/Logs/$APP_ID"'
 print 'APP_DEFAULT_CONFIG_DIR="$HOME/.config/$APP_ID"'
} > "$work/project/project.conf"
content="$(cat "$work/project/README.md")"
print -r -- "${content//@COMMAND@/$name}" > "$work/project/README.md"
chmod +x "$work/project/bin/$name"
/bin/zsh -n "$work/project/bin/$name"
# Publish the completed directory in one rename while holding the target lock.
[[ ! -e "$destination" && ! -L "$destination" ]] || { print -u2 '目标已存在，拒绝覆盖'; exit 1; }
mv "$work/project" "$destination"
print -- "项目已生成: $destination"
