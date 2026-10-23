#!/bin/zsh
# filepath: packages/zsh-kit/lib/console.sh
source "${${(%):-%x}:A:h}/validation.sh"
sk_log() {
    (( $# >= 2 )) || return 2
    case "$1" in info|warning|warn|error|success|ok|debug) ;; *) return 2 ;; esac
    local level="$1"; shift
    if [[ -n "${SK_LOG_SINK:-}" ]]; then "$SK_LOG_SINK" "$level" "$@"; return $?; fi
    local color='' reset=''
    if [[ "${NO_COLOR:-false}" != true && ( -t 2 || "${FORCE_COLOR:-false}" == true ) ]]; then
        color=$'\e[36m'; reset=$'\e[0m'
        [[ "$level" != error ]] || color=$'\e[31m'
    fi
    printf '%s[%s]%s %s\n' "$color" "$level" "$reset" "$*" >&2
}
sk_info() { sk_log info "$@"; }
sk_warning() { sk_log warning "$@"; }
sk_error() { sk_log error "$@"; }
sk_success() { sk_log success "$@"; }
_sk_print_code() {
    if [[ -n "${SK_CODE_SINK:-}" ]]; then "$SK_CODE_SINK" "$@"; else printf '%s\n' "$@"; fi
}
sk_time_start() {
    (( $# <= 2 )) || return 2
    _sk_required "${1-default}" || return 2
    local key="${1:-default}"
    typeset -gA SK_TIMERS
    SK_TIMERS[$key]="$(date +%s)" || return 1
    [[ -z "${2:-}" ]] || sk_info "$2 (开始)"
    return 0
}
sk_time_end() {
    (( $# <= 3 )) || return 2
    _sk_required "${1-default}" || return 2
    case "${3-success}" in info|warning|warn|error|success|ok|debug) ;; *) return 2 ;; esac
    local key="${1:-default}" now
    typeset -gA SK_TIMERS
    [[ -n "${SK_TIMERS[$key]:-}" ]] || return 1
    now="$(date +%s)" || return 1
    sk_log "${3:-success}" "${2:-任务完成}，耗时 $((now - SK_TIMERS[$key]))s"
    unset 'SK_TIMERS[$key]'
}
