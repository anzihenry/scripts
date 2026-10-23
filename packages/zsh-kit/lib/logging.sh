#!/bin/zsh
# filepath: packages/zsh-kit/lib/logging.sh
source "${${(%):-%x}:A:h}/validation.sh"
# 有界日志：按字节轮转，归档清理；系统文件锁协调多个写入进程。

_sk_log_policy() {
  local bytes="${SK_LOG_MAX_BYTES-5242880}" backups="${SK_LOG_BACKUPS-5}" days="${SK_LOG_RETENTION_DAYS-30}"
  _sk_uint "$bytes" 1 1073741824 && _sk_uint "$backups" 1 100 && _sk_uint "$days" 1 3650 || return 2
  SK_MAX_BYTES=$((10#$bytes)) SK_BACKUPS=$((10#$backups)) SK_RETENTION_DAYS=$((10#$days))
}

_sk_trim_log() {
  local target="$1" size temp_file
  size="$(stat -f '%z' "$target")" || return 1
  (( size > SK_MAX_BYTES )) || return 0
  temp_file="$(mktemp "${target}.trim.XXXXXXXX")" || return 1
  if ! tail -c "$SK_MAX_BYTES" "$target" > "$temp_file" || ! mv -f "$temp_file" "$target"; then
    rm -f "$temp_file"
    return 1
  fi
}

_sk_rotate_log() {
  local log_file="$1" index
  rm -f "$log_file.$SK_BACKUPS" || return 1
  for ((index = SK_BACKUPS - 1; index >= 1; index--)); do
    [[ ! -f "$log_file.$index" ]] || mv -f "$log_file.$index" "$log_file.$((index + 1))" || return 1
  done
  [[ ! -f "$log_file" ]] || mv -f "$log_file" "$log_file.1" || return 1
  : > "$log_file"
}

_sk_locked_write() (
  emulate -L zsh
  setopt no_multibyte
  umask 077
  local log_file="$1" data="$2" maintain="${3:-false}"
  local lock_file="$log_file.lock" lock_fd candidate suffix modified cutoff size room part
  zmodload zsh/system || return 1
  # 不跟随符号链接，不处理归档命名之外的文件。
  for candidate in "$log_file" "$lock_file" "$log_file".*(N); do
    [[ "$candidate" == "$log_file" || "$candidate" == "$lock_file" || "${candidate##*.}" == <-> ]] || continue
    if [[ -L "$candidate" || ( -e "$candidate" && ! -f "$candidate" ) ]]; then
      printf '日志路径不是普通文件，拒绝轮转: %s\n' "$candidate" >&2
      return 1
    fi
  done
  : >> "$lock_file" || return 1
  # 内核锁随进程/描述符退出释放，不依赖清理 PID 文件。
  zsystem flock -t 5 -f lock_fd "$lock_file" || return 1
  if [[ "$maintain" == true ]]; then
    cutoff=$(( $(date +%s) - SK_RETENTION_DAYS * 86400 ))
    for candidate in "$log_file".*(N); do
      suffix="${candidate##*.}"
      [[ "$suffix" == <-> && ${#suffix} -le 9 ]] || continue
      modified="$(stat -f '%m' "$candidate")" || return 1
      if (( suffix < 1 || suffix > SK_BACKUPS || modified < cutoff )); then
        rm -f "$candidate" || return 1
      else
        _sk_trim_log "$candidate" || return 1
      fi
    done
  fi
  : >> "$log_file" || return 1
  size="$(stat -f '%z' "$log_file")" || return 1
  if (( size > SK_MAX_BYTES )); then
    # 接管旧的大文件时只保留末尾预算内内容，再作为最近归档保留。
    _sk_trim_log "$log_file" || return 1
    _sk_rotate_log "$log_file" || return 1
    size=0
  fi
  while [[ -n "$data" ]]; do
    if (( size >= SK_MAX_BYTES )); then
      _sk_rotate_log "$log_file" || return 1
      size=0
    fi
    room=$(( SK_MAX_BYTES - size ))
    part="${data[1,room]}"
    printf '%s' "$part" >> "$log_file" || return 1
    size=$(( size + ${#part} ))
    data="${data[${#part}+1,-1]}"
  done
)

sk_append_log() {
    (( $# == 2 )) || return 2
    _sk_required "$1" || return 2
  _sk_log_policy || return 2
  _sk_locked_write "$1" "$2" true
}

_sk_stream_log() {
  emulate -L zsh
  setopt no_multibyte localtraps
  # 让父进程先完成中断摘要并关闭输出；记录器排空管道后再退出。
  trap '' INT TERM HUP
  zmodload zsh/system || return 1
  local log_file="$1" chunk="" failed=false
  while sysread -s 65536 chunk; do
    printf '%s' "$chunk"
    if [[ "$failed" == false ]] && ! _sk_locked_write "$log_file" "$chunk" false; then
      printf '日志写入或轮转失败，终端输出继续保留，请检查: %s\n' "$log_file" >&2
      failed=true
    fi
  done
  [[ "$failed" == false ]]
}

sk_start_capture() {
    (( $# >= 1 && $# <= 2 )) || return 2
    local capture_mode="${2-merged}"
    [[ "$capture_mode" == merged || "$capture_mode" == separate ]] || return 2
    _sk_required "$1" || return 2
  [[ "${SK_CAPTURE_ACTIVE:-false}" != true ]] || { print -u2 "日志捕获已启动"; return 2; }
  _sk_log_policy || return 2
  _sk_locked_write "$1" '' true || return 1
  # Zsh 的进程替换不保证提供 $!；使用私有 FIFO 启动可 wait 的子进程。
  # FIFO 在双方打开后立即删除，正常运行和中断均不留下临时文件。
  local stream_dir stream_fifo
  stream_dir="$(mktemp -d "${TMPDIR:-/tmp}/zsh-kit-log.XXXXXXXX")" || return 1
  stream_fifo="$stream_dir/stream"
  if ! (umask 077; mkfifo "$stream_fifo"); then
    rmdir "$stream_dir"
    return 1
  fi
  if [[ "$capture_mode" == separate ]] && ! (umask 077; mkfifo "$stream_dir/stderr"); then
    rm -f "$stream_fifo"; rmdir "$stream_dir"
    return 1
  fi
  exec {SK_CAPTURE_STDOUT}>&1 {SK_CAPTURE_STDERR}>&2
  setopt localoptions no_bg_nice
  _sk_stream_log "$1" < "$stream_fifo" >&$SK_CAPTURE_STDOUT 2>&$SK_CAPTURE_STDERR &
  SK_CAPTURE_PID=$!
  SK_CAPTURE_STDERR_PID=''
  if [[ "$capture_mode" == separate ]]; then
    _sk_stream_log "$1" < "$stream_dir/stderr" >&$SK_CAPTURE_STDERR 2>&$SK_CAPTURE_STDERR &
    SK_CAPTURE_STDERR_PID=$!
    exec > "$stream_fifo" 2> "$stream_dir/stderr"
  else
    exec > "$stream_fifo" 2>&1
  fi
  SK_CAPTURE_ACTIVE=true
  SK_CAPTURE_DIR="$stream_dir"
  if rm -f "$stream_fifo" "$stream_dir/stderr" && rmdir "$stream_dir"; then
    SK_CAPTURE_DIR=""
  else
    printf '日志通道临时目录清理失败，退出时重试: %s\n' "$stream_dir" >&2
  fi
  # 与业务 EXIT trap 分离；显式退出/正常退出时排空记录器，保留原退出码。
  typeset -ga zshexit_functions
  (( ${zshexit_functions[(Ie)sk_finish_capture]} )) || zshexit_functions+=(sk_finish_capture)
}

sk_finish_capture() {
  local exit_code=$?
  (( $# == 0 )) || return 2
  [[ "${SK_CAPTURE_ACTIVE:-false}" == true ]] || return "$exit_code"
  SK_CAPTURE_ACTIVE=false
  exec 1>&$SK_CAPTURE_STDOUT 2>&$SK_CAPTURE_STDERR
  exec {SK_CAPTURE_STDOUT}>&- {SK_CAPTURE_STDERR}>&-
  local capture_code=0
  wait "$SK_CAPTURE_PID" || capture_code=$?
  if [[ -n "${SK_CAPTURE_STDERR_PID:-}" ]]; then
    wait "$SK_CAPTURE_STDERR_PID" || capture_code=$?
  fi
  if (( capture_code != 0 )); then
    printf '运行日志不完整（记录器退出码 %s）；业务退出码仍为 %s，请检查日志目录权限和剩余空间。\n' "$capture_code" "$exit_code" >&2
  fi
  if [[ -n "${SK_CAPTURE_DIR:-}" ]]; then
    if ! { rm -f "$SK_CAPTURE_DIR/stream" "$SK_CAPTURE_DIR/stderr" && rmdir "$SK_CAPTURE_DIR"; }; then
      printf '日志通道临时目录未能清理，请检查: %s\n' "$SK_CAPTURE_DIR" >&2
    fi
  fi
  return "$exit_code"
}
