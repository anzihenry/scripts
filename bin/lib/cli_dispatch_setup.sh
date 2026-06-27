#!/bin/zsh
# filepath: bin/lib/cli_dispatch_setup.sh

handle_setup_brew() {
  local action="${1:-configure}"
  shift || true

  case "$action" in
    configure)
      has_help_flag "$@" && { print_setup_brew_help; return 0; }
      case "$#" in
        0)
          ;;
        1)
          [[ "$1" == "--dry-run" ]] || {
            usage_error "setup brew configure 不支持参数: $1" print_setup_brew_help
            return 1
          }
          ;;
        *)
          usage_error "setup brew configure 不支持参数: $*" print_setup_brew_help
          return 1
          ;;
      esac
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
  run_bash_script "setup/git_forge_ssh_setup.sh" "$@"
}

handle_setup_github() {
  has_help_flag "$@" && { print_setup_github_help; return 0; }
  validate_setup_github_args "$@" || return 1

  local has_domain="false"
  local has_type="false"
  local arg

  for arg in "$@"; do
    case "$arg" in
      -d|--domain) has_domain="true" ;;
      -t|--type) has_type="true" ;;
    esac
  done

  local -a forwarded_args=()
  [[ "$has_domain" == "false" ]] && forwarded_args+=(--domain github.com)
  [[ "$has_type" == "false" ]] && forwarded_args+=(--type personal)
  forwarded_args+=("$@")

  handle_setup_git "${forwarded_args[@]}"
}

handle_setup() {
  local action="${1:-help}"
  shift || true

  case "$action" in
    shell)
      has_help_flag "$@" && { print_setup_shell_help; return 0; }
      reject_extra_args print_setup_shell_help "$@" || return 1
      run_zsh_script "setup/ohmyzsh-setup.sh" "$@"
      ;;
    brew)
      handle_setup_brew "$@"
      ;;
    packages)
      has_help_flag "$@" && { print_setup_packages_help; return 0; }
      reject_extra_args print_setup_packages_help "$@" || return 1
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
