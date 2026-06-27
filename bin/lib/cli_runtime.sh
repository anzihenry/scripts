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
