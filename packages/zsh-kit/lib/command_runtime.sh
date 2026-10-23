#!/bin/zsh
# filepath: packages/zsh-kit/lib/command_runtime.sh
source "${${(%):-%x}:A:h}/console.sh"

sk_command_preview() {
  (( $# > 0 )) || return 2
  _sk_required "$1" || return 2
  local parts=()
  local arg

  for arg in "$@"; do
    parts+=("$(printf '%q' "$arg")")
  done

  local IFS=' '
  printf '%s' "${parts[*]}"
}

sk_run_command() {
    (( $# > 0 )) || return 2
    _sk_required "$1" || return 2
    _sk_bool "${SK_DRY_RUN-false}" || return 2
  if [[ "${SK_DRY_RUN:-false}" == "true" ]]; then
    sk_print_code "$(sk_command_preview "$@")"
    return 0
  fi

  "$@"
}

sk_run_logged_command() {
    (( $# >= 2 )) || return 2
    _sk_required "$2" || return 2
    _sk_bool "${SK_DRY_RUN-false}" || return 2
  local description="$1"
  shift

  if [[ "${SK_DRY_RUN:-false}" == "true" ]]; then
    if [[ -n "$description" ]]; then
      sk_info "[dry-run] $description"
    fi
    sk_print_code "$(sk_command_preview "$@")"
    return 0
  fi

  if [[ -n "$description" ]]; then
    sk_info "$description"
  fi

  "$@"
}

sk_run_timed_command_or_fail() {
    (( $# >= 6 )) || return 2
    _sk_required "$1" || return 2
    _sk_required "$6" || return 2
    _sk_bool "${SK_DRY_RUN-false}" || return 2
  local timer_key="$1"
  local start_message="$2"
  local success_message="$3"
  local failure_message="$4"
  local failure_detail="$5"
  shift 5

  sk_time_start "$timer_key" "$start_message"
  local code=0
  sk_run_logged_command "$start_message" "$@" || code=$?
  if (( code != 0 )); then
    sk_time_end "$timer_key" "$failure_message" "error"
    sk_error "$failure_detail"
    return "$code"
  fi
  sk_time_end "$timer_key" "$success_message"
}
