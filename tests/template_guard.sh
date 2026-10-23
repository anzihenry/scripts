#!/bin/zsh
# filepath: tests/template_guard.sh
set -euo pipefail
ROOT="${0:A:h:h}"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/template guard.XXXXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
project="$SANDBOX/renamed project"
description='literal $HOME `touch SHOULD_NOT_EXIST` "quotes" $(false)'
/bin/zsh "$ROOT/tools/create_zsh_project.sh" --name daily-tool --description "$description" --repository https://example.invalid/daily-tool "$project"
(
 source "$project/project.conf"
 [[ "$APP_COMMAND" == daily-tool && "$APP_ENV_PREFIX" == DAILY_TOOL && "$APP_DESCRIPTION" == "$description" ]]
 [[ "$APP_KIT_VERSION" == "$(cat "$project/vendor/zsh-kit/VERSION")" ]]
)
[[ ! -e "$project/SHOULD_NOT_EXIST" && ! -e SHOULD_NOT_EXIST ]]
# Neither a repository checkout nor application modules are needed at runtime.
(cd "$project"; /bin/zsh tests/run.sh)
/bin/zsh "$ROOT/tools/create_zsh_project.sh" --name daily-tool "$project" 2>/dev/null && exit 1
/bin/zsh "$ROOT/tools/create_zsh_project.sh" --name '../bad' "$SANDBOX/bad" 2>/dev/null && exit 1
/bin/zsh "$ROOT/tools/create_zsh_project.sh" --name 2>/dev/null && exit 1
[[ ! -e "$SANDBOX/bad" ]]
for file in "$project"/bin/* "$project"/src/* "$project/project.conf" "$project/README.md"; do
 text="$(cat "$file")"
 [[ "$text" != *macos-scripts* && "$text" != *'@COMMAND@'* ]]
done
print 'Template guard passed'
