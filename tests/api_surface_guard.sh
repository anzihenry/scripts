#!/bin/zsh
# filepath: tests/api_surface_guard.sh
set -euo pipefail
ROOT="${0:A:h:h}"
sandbox="$(mktemp -d "${TMPDIR:-/tmp}/api-surface.XXXXXXXX")"
trap 'rm -rf "$sandbox"' EXIT
/bin/zsh "$ROOT/tools/vendor_zsh_kit.sh" --check "$ROOT/tests/fixtures/vendor/zsh-kit-0.1.0" >/dev/null
# Application code and templates must not call private component functions.
if /usr/bin/grep -En '(^|[^[:alnum:]_])_sk_[[:alnum:]_]+' "$ROOT"/lib/*.sh "$ROOT"/setup/lib/*.sh "$ROOT"/maintain/lib/*.sh "$ROOT"/templates/zsh-cli/src/*.sh "$ROOT"/bin/lib/*.sh "$ROOT"/setup/*.sh "$ROOT"/maintain/*.sh "$ROOT"/examples/file-organizer/src/*.sh; then
 print -u2 '应用依赖了组件私有函数'; exit 1
fi
/bin/zsh "$ROOT/packages/zsh-kit/tests/consumer.sh" "$ROOT/tests/fixtures/vendor/zsh-kit-0.1.0" > "$sandbox/old" 2> "$sandbox/old.err"
/bin/zsh "$ROOT/packages/zsh-kit/tests/consumer.sh" "$ROOT/packages/zsh-kit" > "$sandbox/new" 2> "$sandbox/new.err"
cmp -s "$sandbox/old" "$sandbox/new"
cmp -s "$sandbox/old.err" "$sandbox/new.err"
# Shared application modules resolve their own location, independent of cwd/$0 options.
/bin/zsh -c '
 set -euo pipefail
 unsetopt FUNCTION_ARGZERO
 cd /
 for module in setup/lib/homebrew_config.sh setup/lib/brew_helpers.sh maintain/lib/macos_installer_utils.sh; do
   source "$1/$module"
 done
 (( ${+functions[resolve_homebrew_bin]} && ${+functions[bh_reset_summary]} && ${+functions[sanitize_key]} ))
' zsh "$ROOT"
# A missing public entry must be detected without relying on source text matching.
cp -R "$ROOT/packages/zsh-kit" "$sandbox/broken"
print 'sk_nonexistent_api' >> "$sandbox/broken/API.txt"
/bin/zsh "$sandbox/broken/tests/api.sh" > /dev/null 2>&1 && { print -u2 'API 清单漂移未被发现'; exit 1; }
print 'API surface and old/new consumer behavior passed'
