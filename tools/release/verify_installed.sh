#!/bin/zsh
# filepath: tools/release/verify_installed.sh
set -euo pipefail
(( $# == 2 )) || exit 2
[[ "$1" =~ '^v[0-9]+\.[0-9]+\.[0-9]+$' && -x "$2" ]] || exit 2
actual="$("$2" --version)"
[[ "$actual" == "macos-scripts $1" ]] || { print -u2 -- "安装版本不匹配: 目标=$1，实际=$actual"; exit 1; }
print -- "安装版本已验证: $actual"
