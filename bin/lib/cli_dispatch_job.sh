#!/bin/zsh
# filepath: bin/lib/cli_dispatch_job.sh

handle_job() {
  local action="${1:-help}"
  shift || true

  case "$action" in
    list)
      has_help_flag "$@" && { print_job_list_help; return 0; }
      validate_job_list_args "$@" || return 1
      run_scheduler_action list "$@"
      ;;
    status)
      has_help_flag "$@" && { print_job_status_help; return 0; }
      validate_job_name_action_args status print_job_status_help false "$@" || return 1
      run_scheduler_action status "$@"
      ;;
    create)
      has_help_flag_before_separator "$@" && { print_job_create_help; return 0; }
      validate_job_create_args "$@" || return 1
      run_scheduler_action create "$@"
      ;;
    enable)
      has_help_flag "$@" && { print_job_enable_help; return 0; }
      validate_job_name_action_args enable print_job_enable_help true "$@" || return 1
      run_scheduler_action enable "$@"
      ;;
    disable)
      has_help_flag "$@" && { print_job_disable_help; return 0; }
      validate_job_name_action_args disable print_job_disable_help true "$@" || return 1
      run_scheduler_action disable "$@"
      ;;
    delete)
      has_help_flag "$@" && { print_job_delete_help; return 0; }
      validate_job_name_action_args delete print_job_delete_help true "$@" || return 1
      run_scheduler_action delete "$@"
      ;;
    help|-h|--help)
      print_job_help
      ;;
    *)
      command_error "未知的 job 子命令: $action" print_job_help
      ;;
  esac
}
