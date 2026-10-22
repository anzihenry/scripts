#!/bin/zsh
# filepath: bin/lib/cli_dispatch_setup.sh
source "${${(%):-%x}:A:h}/../../setup/lib/setup_options.sh"

dispatch_setup_argless_command() {
  local help_func="$1"
  local script_path="$2"
  shift 2

  has_help_flag "$@" && {
    "$help_func"
    return 0
  }

  reject_extra_args "$help_func" "$@" || return 1
  run_zsh_script "$script_path" "$@"
}

handle_setup_brew() {
  local action="${1:-configure}"
  shift || true

  case "$action" in
    configure)
      has_help_flag "$@" && { print_setup_brew_help; return 0; }
      validate_setup_brew_configure_args "$@" || return 1
      run_zsh_script "setup/homebrew-setup.sh" "$@"
      ;;
    help|-h|--help)
      print_setup_brew_help
      ;;
    *)
      command_error "未知的 setup brew 子命令: $action" print_setup_brew_help
      ;;
  esac
}

handle_setup_git() {
  has_help_flag "$@" && { print_setup_git_help; return 0; }
  validate_setup_git_args "$@" || return 1
  run_zsh_script "setup/git_forge_ssh_setup.sh" "$@"
}

handle_setup_github() {
  has_help_flag "$@" && { print_setup_github_help; return 0; }
  validate_setup_github_args "$@" || return 1

  local -a forwarded_args=()
  load_setup_github_forwarded_args forwarded_args "$@"
  handle_setup_git "${forwarded_args[@]}"
}

handle_setup() {
  local action="${1:-help}"
  shift || true

  case "$action" in
    shell)
      has_help_flag "$@" && { print_setup_shell_help; return 0; }
      parse_shell_options "$@" || return $?
      run_zsh_script "setup/ohmyzsh-setup.sh" "$@"
      ;;
    brew)
      handle_setup_brew "$@"
      ;;
    packages)
      has_help_flag "$@" && { print_setup_packages_help; return 0; }
      parse_setup_options "$@" || return $?
      run_zsh_script "setup/macos-setup.sh" "$@"
      ;;
    git)
      handle_setup_git "$@"
      ;;
    github)
      handle_setup_github "$@"
      ;;
    help|-h|--help)
      print_setup_help
      ;;
    *)
      command_error "未知的 setup 子命令: $action" print_setup_help
      ;;
  esac
}
