#!/bin/zsh
# filepath: packages/zsh-kit/tests/api.sh
set -euo pipefail
ROOT="${0:A:h:h}"
actual="$(/bin/zsh -f -c 'source "$1/lib/zsh-kit.sh"; print -rl -- ${(ok)functions[(I)sk_*]}' zsh "$ROOT")"
[[ "$actual" == "$(cat "$ROOT/API.txt")" ]] || { print -u2 '公开函数与 API.txt 不一致'; exit 1; }
sandbox="$(mktemp -d "${TMPDIR:-/tmp}/kit-api.XXXXXXXX")"
trap 'rm -rf "$sandbox"' EXIT
code=0
/bin/zsh -f -c '
 source "$1/lib/zsh-kit.sh"
 sk_start_capture "$2/log" separate || exit 1
 source "$1/lib/zsh-kit.sh"
 print PAYLOAD
 sk_error DIAGNOSTIC
 exit 7
' zsh "$ROOT" "$sandbox" > "$sandbox/out" 2> "$sandbox/err" || code=$?
[[ "$code" == 7 && "$(cat "$sandbox/out")" == PAYLOAD ]]
[[ "$(cat "$sandbox/err")" == *DIAGNOSTIC* && "$(cat "$sandbox/err")" != *PAYLOAD* ]]
[[ "$(cat "$sandbox/log")" == *PAYLOAD* && "$(cat "$sandbox/log")" == *DIAGNOSTIC* ]]
source "$ROOT/lib/zsh-kit.sh"
print original > "$sandbox/config"
print replacement > "$sandbox/candidate"
sk_commit_config_candidate "$sandbox/config" "$sandbox/candidate" 600
[[ "$(cat "$sandbox/config")" == replacement && ! -e "$sandbox/candidate" ]]
[[ "$(stat -f '%Lp' "$sandbox/config")" == 600 ]]
print 'API manifest, separated capture/reload and candidate commit passed'
