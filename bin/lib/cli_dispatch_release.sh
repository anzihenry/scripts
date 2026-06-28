#!/bin/zsh
# filepath: bin/lib/cli_dispatch_release.sh

handle_release_publish() {
  has_help_flag "$@" && { print_release_publish_help; return 0; }
  validate_release_publish_args "$@" || return 1

  local -a forwarded_args=()
  load_release_forwarded_args forwarded_args publish "$@"
  run_release_script "${forwarded_args[@]}"
}

handle_release_verify() {
  has_help_flag "$@" && { print_release_verify_help; return 0; }
  validate_release_verify_args "$@" || return 1

  local -a forwarded_args=()
  load_release_forwarded_args forwarded_args verify "$@"
  run_release_script "${forwarded_args[@]}"
}

handle_release() {
  local action="${1:-help}"
  shift || true

  case "$action" in
    publish)
      handle_release_publish "$@"
      ;;
    verify)
      handle_release_verify "$@"
      ;;
    help|-h|--help)
      print_release_help
      ;;
    *)
      command_error "未知的 release 子命令: $action" print_release_help
      ;;
  esac
}
