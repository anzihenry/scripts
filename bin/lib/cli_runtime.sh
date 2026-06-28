#!/bin/zsh
# filepath: bin/lib/cli_runtime.sh

run_zsh_script() {
  local relative_path="$1"
  shift
  zsh "$REPO_ROOT/$relative_path" "$@"
}

run_bash_script() {
  local relative_path="$1"
  shift
  bash "$REPO_ROOT/$relative_path" "$@"
}

load_forwarded_args() {
  local target_name="$1"
  local builder_func="$2"
  shift 2

  local -a collected_args=()
  local arg
  while IFS= read -r arg; do
    collected_args+=("$arg")
  done < <("$builder_func" "$@")

  local serialized=""
  for arg in "${collected_args[@]}"; do
    serialized+=" ${(qqq)arg}"
  done

  eval "$target_name=($serialized)"
}

run_release_script() {
  run_bash_script "maintain/github_release_publish.sh" "$@"
}

run_scheduler_action() {
  local action="$1"
  shift
  run_zsh_script "job/scheduler.sh" "$action" "$@"
}

run_maintain_installer_action() {
  local action="$1"
  shift
  run_zsh_script "maintain/macos_sys_usb_maker.sh" "$action" "$@"
}

usage_error() {
  local message="$1"
  local help_func="$2"

  error "参数错误: $message"
  echo
  "$help_func"
  return 1
}

command_error() {
  local message="$1"
  local help_func="$2"

  error "$message"
  echo
  "$help_func"
  return 1
}

is_help_arg() {
  case "$1" in
    help|-h|--help) return 0 ;;
    *) return 1 ;;
  esac
}

has_help_flag() {
  local arg
  for arg in "$@"; do
    is_help_arg "$arg" && return 0
  done
  return 1
}

has_help_flag_before_separator() {
  local arg
  for arg in "$@"; do
    [[ "$arg" == "--" ]] && return 1
    is_help_arg "$arg" && return 0
  done
  return 1
}

reject_extra_args() {
  local help_func="$1"
  shift

  [[ $# -eq 0 ]] && return 0
  usage_error "该命令不接受额外参数: $*" "$help_func"
}
