#!/bin/zsh
# filepath: lib/logging.sh
# 有界日志：按字节轮转，归档清理；系统文件锁协调多个写入进程。

ml_log_policy() {
  ML_MAX_BYTES="${MACOS_SCRIPTS_LOG_MAX_BYTES:-5242880}"
  ML_BACKUPS="${MACOS_SCRIPTS_LOG_BACKUPS:-5}"
  ML_RETENTION_DAYS="${MACOS_SCRIPTS_LOG_RETENTION_DAYS:-30}"
  local value
  for value in "$ML_MAX_BYTES" "$ML_BACKUPS" "$ML_RETENTION_DAYS"; do
    if [[ "$value" != <-> || ${#value} -gt 10 ]] || (( value < 1 )); then
      printf '日志轮转参数必须为正整数。\n' >&2
      return 1
    fi
  done
  if (( ML_MAX_BYTES > 1073741824 || ML_BACKUPS > 100 || ML_RETENTION_DAYS > 3650 )); then
    printf '日志轮转上限：单文件 1 GiB、100 份归档、3650 天。\n' >&2
    return 1
  fi
}

ml_trim_log() {
  local target="$1" size temp_file
  size="$(stat -f '%z' "$target")" || return 1
  (( size > ML_MAX_BYTES )) || return 0
  temp_file="$(mktemp "${target}.trim.XXXXXXXX")" || return 1
  if ! tail -c "$ML_MAX_BYTES" "$target" > "$temp_file" || ! mv -f "$temp_file" "$target"; then
    rm -f "$temp_file"
    return 1
  fi
}

ml_rotate_log() {
  local log_file="$1" index
  rm -f "$log_file.$ML_BACKUPS" || return 1
  for ((index = ML_BACKUPS - 1; index >= 1; index--)); do
    [[ ! -f "$log_file.$index" ]] || mv -f "$log_file.$index" "$log_file.$((index + 1))" || return 1
  done
  [[ ! -f "$log_file" ]] || mv -f "$log_file" "$log_file.1" || return 1
  : > "$log_file"
}

ml_locked_write() (
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
    cutoff=$(( $(date +%s) - ML_RETENTION_DAYS * 86400 ))
    for candidate in "$log_file".*(N); do
      suffix="${candidate##*.}"
      [[ "$suffix" == <-> && ${#suffix} -le 9 ]] || continue
      modified="$(stat -f '%m' "$candidate")" || return 1
      if (( suffix < 1 || suffix > ML_BACKUPS || modified < cutoff )); then
        rm -f "$candidate" || return 1
      else
        ml_trim_log "$candidate" || return 1
      fi
    done
  fi
  : >> "$log_file" || return 1
  size="$(stat -f '%z' "$log_file")" || return 1
  if (( size > ML_MAX_BYTES )); then
    # 接管旧的大文件时只保留末尾预算内内容，再作为最近归档保留。
    ml_trim_log "$log_file" || return 1
    ml_rotate_log "$log_file" || return 1
    size=0
  fi
  while [[ -n "$data" ]]; do
    if (( size >= ML_MAX_BYTES )); then
      ml_rotate_log "$log_file" || return 1
      size=0
    fi
    room=$(( ML_MAX_BYTES - size ))
    part="${data[1,room]}"
    printf '%s' "$part" >> "$log_file" || return 1
    size=$(( size + ${#part} ))
    data="${data[${#part}+1,-1]}"
  done
)

ml_append_log() {
  ml_log_policy || return 1
  ml_locked_write "$1" "$2" true
}

ml_stream_log() {
  emulate -L zsh
  setopt no_multibyte localtraps
  # 让父进程先完成中断摘要并关闭输出；记录器排空管道后再退出。
  trap '' INT TERM HUP
  zmodload zsh/system || return 1
  local log_file="$1" chunk="" failed=false
  while sysread -s 65536 chunk; do
    printf '%s' "$chunk"
    if [[ "$failed" == false ]] && ! ml_locked_write "$log_file" "$chunk" false; then
      printf '日志写入或轮转失败，终端输出继续保留，请检查: %s\n' "$log_file" >&2
      failed=true
    fi
  done
  [[ "$failed" == false ]]
}

ml_start_capture() {
  ml_log_policy || return 1
  ml_locked_write "$1" '' true || return 1
  # Zsh 的进程替换不保证提供 $!；使用私有 FIFO 启动可 wait 的子进程。
  # FIFO 在双方打开后立即删除，正常运行和中断均不留下临时文件。
  local stream_dir stream_fifo
  stream_dir="$(mktemp -d "${TMPDIR:-/tmp}/macos-scripts-log.XXXXXXXX")" || return 1
  stream_fifo="$stream_dir/stream"
  if ! (umask 077; mkfifo "$stream_fifo"); then
    rmdir "$stream_dir"
    return 1
  fi
  exec {ML_CAPTURE_STDOUT}>&1 {ML_CAPTURE_STDERR}>&2
  setopt localoptions no_bg_nice
  ml_stream_log "$1" < "$stream_fifo" >&$ML_CAPTURE_STDOUT 2>&$ML_CAPTURE_STDERR &
  ML_CAPTURE_PID=$!
  exec > "$stream_fifo" 2>&1
  ML_CAPTURE_ACTIVE=true
  ML_CAPTURE_DIR="$stream_dir"
  if rm -f "$stream_fifo" && rmdir "$stream_dir"; then
    ML_CAPTURE_DIR=""
  else
    printf '日志通道临时目录清理失败，退出时重试: %s\n' "$stream_dir" >&2
  fi
  # 与业务 EXIT trap 分离；显式退出/正常退出时排空记录器，保留原退出码。
  typeset -ga zshexit_functions
  (( ${zshexit_functions[(Ie)ml_finish_capture]} )) || zshexit_functions+=(ml_finish_capture)
}

ml_finish_capture() {
  local exit_code=$?
  [[ "${ML_CAPTURE_ACTIVE:-false}" == true ]] || return "$exit_code"
  ML_CAPTURE_ACTIVE=false
  exec 1>&$ML_CAPTURE_STDOUT 2>&$ML_CAPTURE_STDERR
  exec {ML_CAPTURE_STDOUT}>&- {ML_CAPTURE_STDERR}>&-
  local capture_code=0
  wait "$ML_CAPTURE_PID" || capture_code=$?
  if (( capture_code != 0 )); then
    printf '运行日志不完整（记录器退出码 %s）；业务退出码仍为 %s，请检查日志目录权限和剩余空间。\n' "$capture_code" "$exit_code" >&2
  fi
  if [[ -n "${ML_CAPTURE_DIR:-}" ]]; then
    if ! { rm -f "$ML_CAPTURE_DIR/stream" && rmdir "$ML_CAPTURE_DIR"; }; then
      printf '日志通道临时目录未能清理，请检查: %s\n' "$ML_CAPTURE_DIR" >&2
    fi
  fi
  return "$exit_code"
}
