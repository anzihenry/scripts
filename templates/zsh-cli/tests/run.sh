#!/bin/zsh
# filepath: tests/run.sh
set -euo pipefail
ROOT="${0:A:h:h}"
source "$ROOT/project.conf"
[[ "$APP_KIT_VERSION" == "$(cat "$ROOT/vendor/zsh-kit/VERSION")" ]]
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/cli-test.XXXXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
mkdir "$HOME"
export "${APP_ENV_PREFIX}_LOG_DIR=$SANDBOX/logs"
export "${APP_ENV_PREFIX}_CONFIG_DIR=$SANDBOX/config"
for file in "$ROOT"/bin/*(N.) "$ROOT"/src/*.sh(N.) "$ROOT"/scripts/*.sh(N.); do /bin/zsh -n "$file"; done
/bin/zsh "$ROOT/scripts/vendor_zsh_kit.sh" --check "$ROOT/vendor/zsh-kit"
/bin/zsh "$ROOT/vendor/zsh-kit/tests/contract.sh"
/bin/zsh "$ROOT/bin/$APP_COMMAND" --help >/dev/null
[[ "$(/bin/zsh "$ROOT/bin/$APP_COMMAND" --version)" == "$APP_COMMAND $APP_VERSION" ]]
/bin/zsh "$ROOT/bin/$APP_COMMAND" nonsense 2>/dev/null && exit 1
/bin/zsh "$ROOT/bin/$APP_COMMAND" hello --dry-run >/dev/null
[[ ! -e "$SANDBOX/logs" && ! -e "$SANDBOX/config" ]]
/bin/zsh "$ROOT/bin/$APP_COMMAND" hello >/dev/null
/bin/zsh "$ROOT/bin/$APP_COMMAND" hello >/dev/null
[[ -s "$SANDBOX/logs/run.log" && ! -e "$SANDBOX/config" ]]
print 'Generated CLI tests passed'
