#!/bin/zsh
# filepath: bin/lib/help_router.sh

handle_help() {
  local group="${1:-}"
  local action="${2:-}"
  local subaction="${3:-}"

  case "$group" in
    "") print_main_help ;;
    setup)
      case "$action" in
        ""|help) print_setup_help ;;
        shell) print_setup_shell_help ;;
        brew) print_setup_brew_help ;;
        packages) print_setup_packages_help ;;
        git) print_setup_git_help ;;
        github) print_setup_github_help ;;
        *) command_error "未知的 setup 帮助主题: $action" print_setup_help ;;
      esac
      ;;
    maintain)
      case "$action" in
        ""|help) print_maintain_help ;;
        brew) print_maintain_brew_help ;;
        installer)
          case "$subaction" in
            ""|help) print_maintain_installer_help ;;
            list) print_maintain_installer_list_help ;;
            download) print_maintain_installer_download_help ;;
            create) print_maintain_installer_create_help ;;
            *) command_error "未知的 maintain installer 帮助主题: $subaction" print_maintain_installer_help ;;
          esac
          ;;
        *) command_error "未知的 maintain 帮助主题: $action" print_maintain_help ;;
      esac
      ;;
    release)
      case "$action" in
        ""|help) print_release_help ;;
        publish) print_release_publish_help ;;
        verify) print_release_verify_help ;;
        *) command_error "未知的 release 帮助主题: $action" print_release_help ;;
      esac
      ;;
    job)
      case "$action" in
        ""|help) print_job_help ;;
        list) print_job_list_help ;;
        status) print_job_status_help ;;
        create) print_job_create_help ;;
        enable) print_job_enable_help ;;
        disable) print_job_disable_help ;;
        delete) print_job_delete_help ;;
        *) command_error "未知的 job 帮助主题: $action" print_job_help ;;
      esac
      ;;
    lint)
      case "$action" in
        ""|help) print_lint_help ;;
        check) print_lint_check_help ;;
        fix) print_lint_fix_help ;;
        *) command_error "未知的 lint 帮助主题: $action" print_lint_help ;;
      esac
      ;;
    *)
      command_error "未知的帮助主题: $group" print_main_help
      ;;
  esac
}
