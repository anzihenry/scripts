#!/bin/zsh
# filepath: lib/command_runtime.sh
source "${${(%):-%x}:A:h}/../packages/zsh-kit/lib/command_runtime.sh"
_ms_command_log() { local level="$1"; shift; "$level" "$@"; }
command_preview() { local SK_LOG_SINK=_ms_command_log SK_CODE_SINK=print_code; local SK_DRY_RUN="${DRY_RUN:-false}"; sk_command_preview "$@"; }
run_command() { local SK_LOG_SINK=_ms_command_log SK_CODE_SINK=print_code; local SK_DRY_RUN="${DRY_RUN:-false}"; sk_run_command "$@"; }
run_logged_command() { local SK_LOG_SINK=_ms_command_log SK_CODE_SINK=print_code; local SK_DRY_RUN="${DRY_RUN:-false}"; sk_run_logged_command "$@"; }
run_timed_command_or_fail() { local SK_LOG_SINK=_ms_command_log SK_CODE_SINK=print_code; local SK_DRY_RUN="${DRY_RUN:-false}"; sk_run_timed_command_or_fail "$@"; }
