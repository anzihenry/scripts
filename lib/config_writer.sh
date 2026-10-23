#!/bin/zsh
# filepath: lib/config_writer.sh
source "${${(%):-%x}:A:h}/resource_lock.sh"
source "${${(%):-%x}:A:h}/../packages/zsh-kit/lib/config_writer.sh"
commit_config_candidate() { local SK_LOCK_TIMEOUT="${MACOS_SCRIPTS_LOCK_TIMEOUT:-10}"; sk_commit_config_candidate "$@"; }
write_managed_block() {
    local SK_LOCK_TIMEOUT="${MACOS_SCRIPTS_LOCK_TIMEOUT:-10}" validate=false
    [[ "${1:t}" != .zshrc ]] || validate=true
    sk_write_managed_block "$1" "$2" "$3" "$4" "${5:-false}" "${6:-managed by}" "$validate"
}
write_managed_file() { local SK_LOCK_TIMEOUT="${MACOS_SCRIPTS_LOCK_TIMEOUT:-10}"; sk_write_managed_file "$@"; }
set_ini_values() { local SK_LOCK_TIMEOUT="${MACOS_SCRIPTS_LOCK_TIMEOUT:-10}"; sk_set_ini_values "$@"; }
set_ini_value() { local SK_LOCK_TIMEOUT="${MACOS_SCRIPTS_LOCK_TIMEOUT:-10}"; sk_set_ini_value "$@"; }
update_shell_config() {
    write_managed_block "$HOME/.zshrc" "$1" macos-setup "$2" || return 1
    success "$1 环境配置已就绪"
}
