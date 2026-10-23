#!/bin/zsh
# filepath: lib/logging.sh
source "${${(%):-%x}:A:h}/../packages/zsh-kit/lib/logging.sh"
# BEGIN APP ADAPTER
_ms_log_config() {
  SK_LOG_MAX_BYTES="${MACOS_SCRIPTS_LOG_MAX_BYTES:-5242880}"
  SK_LOG_BACKUPS="${MACOS_SCRIPTS_LOG_BACKUPS:-5}"
  SK_LOG_RETENTION_DAYS="${MACOS_SCRIPTS_LOG_RETENTION_DAYS:-30}"
}
ml_append_log() { _ms_log_config; sk_append_log "$@"; }
ml_start_capture() { _ms_log_config; sk_start_capture "$@"; }
ml_finish_capture() { sk_finish_capture "$@"; }
# END APP ADAPTER
