#!/bin/zsh
# filepath: bin/lib/cli_dispatch_maintain.sh

handle_maintain_installer() {
  local action="${1:-help}"
  shift || true

  case "$action" in
    list)
      has_help_flag "$@" && { print_maintain_installer_list_help; return 0; }
      validate_installer_list_args "$@" || return 1
      run_maintain_installer_action list "$@"
      ;;
    download)
      has_help_flag "$@" && { print_maintain_installer_download_help; return 0; }
      validate_installer_download_args "$@" || return 1
      run_maintain_installer_action download "$@"
      ;;
    create)
      has_help_flag "$@" && { print_maintain_installer_create_help; return 0; }
      validate_installer_create_args "$@" || return 1
      run_maintain_installer_action create "$@"
      ;;
    help|-h|--help)
      print_maintain_installer_help
      ;;
    *)
      command_error "未知的 maintain installer 子命令: $action" print_maintain_installer_help
      ;;
  esac
}

handle_maintain() {
  local action="${1:-help}"
  shift || true

  case "$action" in
    brew)
      has_help_flag "$@" && { print_maintain_brew_help; return 0; }
      validate_maintain_brew_args "$@" || return 1
      run_zsh_script "maintain/formulaes_casks_updater.sh" "$@"
      ;;
    installer)
      handle_maintain_installer "$@"
      ;;
    help|-h|--help)
      print_maintain_help
      ;;
    *)
      command_error "未知的 maintain 子命令: $action" print_maintain_help
      ;;
  esac
}
