#!/bin/bash
# filepath: maintain/lib/command_runtime.sh

command_preview() {
  local parts=()
  local arg

  for arg in "$@"; do
    parts+=("$(printf '%q' "$arg")")
  done

  local IFS=' '
  printf '%s' "${parts[*]}"
}

run_command() {
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    print_code "$(command_preview "$@")"
    return 0
  fi

  "$@"
}

run_logged_command() {
  local description="$1"
  shift

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    if [[ -n "$description" ]]; then
      info "[dry-run] $description"
    fi
    print_code "$(command_preview "$@")"
    return 0
  fi

  if [[ -n "$description" ]]; then
    info "$description"
  fi

  "$@"
}

run_timed_command_or_fail() {
  local timer_key="$1"
  local start_message="$2"
  local success_message="$3"
  local failure_message="$4"
  local failure_detail="$5"
  shift 5

  log_time_start "$timer_key" "$start_message"
  if ! run_logged_command "$start_message" "$@"; then
    log_time_end "$timer_key" "$failure_message" "error"
    log_fatal "$failure_detail"
  fi
  log_time_end "$timer_key" "$success_message"
}
