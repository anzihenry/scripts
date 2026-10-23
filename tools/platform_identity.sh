#!/bin/zsh
# filepath: tools/platform_identity.sh
# Read-only environment identity and optional runner expectations.
set -euo pipefail
expected_os="${TEST_EXPECT_OS_MAJOR:-}" expected_arch="${TEST_EXPECT_ARCH:-}"
[[ -z "$expected_os" || ( "$expected_os" == <-> && ${#expected_os} -le 2 ) ]] || exit 2
[[ -z "$expected_arch" || "$expected_arch" == arm64 || "$expected_arch" == x86_64 ]] || exit 2
(( $# == 0 )) || exit 2
command -v sw_vers >/dev/null || { print -u2 '需要 macOS'; exit 1; }
os="$(sw_vers -productVersion)"; build="$(sw_vers -buildVersion)"; arch="$(uname -m)"
print -r -- "os=$os" "build=$build" "arch=$arch" "zsh=$ZSH_VERSION"
major="${os%%.*}"
[[ "$major" == <-> ]] && (( major >= 14 )) || { print -u2 '需要 macOS 14+'; exit 1; }
[[ -z "$expected_os" || "$major" == "$expected_os" ]] || { print -u2 "runner 系统不符，期望 $expected_os，实际 $major"; exit 1; }
[[ -z "$expected_arch" || "$arch" == "$expected_arch" ]] || { print -u2 "runner 架构不符，期望 $expected_arch，实际 $arch"; exit 1; }
