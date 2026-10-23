#!/bin/zsh
# filepath: lib/resource_lock.sh
source "${${(%):-%x}:A:h}/../packages/zsh-kit/lib/resource_lock.sh"
# BEGIN APP ADAPTER
resource_lock_acquire() { local SK_LOCK_TIMEOUT="${MACOS_SCRIPTS_LOCK_TIMEOUT:-10}"; sk_resource_lock_acquire "$@"; }
with_resource_lock() ( local resource="$1"; shift; resource_lock_acquire "$resource" || return 1; "$@" )
resource_locks_release_owned() { sk_resource_locks_release_owned "$@"; }
homebrew_resource_lock() {
    local brew_bin="${1:-}" prefix
    [[ -n "$brew_bin" ]] || brew_bin="$(resolve_homebrew_bin)" || return 1
    prefix="$("$brew_bin" --prefix)" || return 1
    [[ -n "$prefix" && "$prefix" == /* ]] || { error "Homebrew prefix 无效"; return 1; }
    resource_lock_acquire "${prefix:A}/.macos-scripts-resource"
}
# END APP ADAPTER
