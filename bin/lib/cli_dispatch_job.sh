#!/bin/zsh
# filepath: bin/lib/cli_dispatch_job.sh

handle_job() {
  local action="${1:-help}"
  shift || true

  case "$action" in
    list)
      has_help_flag "$@" && { print_job_list_help; return 0; }
      validate_job_list_args "$@" || return 1
      run_zsh_script "job/scheduler.sh" list "$@"
      ;;
    status)
      has_help_flag "$@" && { print_job_status_help; return 0; }
      validate_job_name_action_args status print_job_status_help false "$@" || return 1
      run_zsh_script "job/scheduler.sh" status "$@"
      ;;
    create)
      has_help_flag_before_separator "$@" && { print_job_create_help; return 0; }
      validate_job_create_args "$@" || return 1
      run_zsh_script "job/scheduler.sh" create "$@"
      ;;
    enable)
      has_help_flag "$@" && { print_job_enable_help; return 0; }
      validate_job_name_action_args enable print_job_enable_help true "$@" || return 1
      run_zsh_script "job/scheduler.sh" enable "$@"
      ;;
    disable)
      has_help_flag "$@" && { print_job_disable_help; return 0; }
      validate_job_name_action_args disable print_job_disable_help true "$@" || return 1
      run_zsh_script "job/scheduler.sh" disable "$@"
      ;;
    delete)
      has_help_flag "$@" && { print_job_delete_help; return 0; }
      validate_job_name_action_args delete print_job_delete_help true "$@" || return 1
      run_zsh_script "job/scheduler.sh" delete "$@"
      ;;
    help|-h|--help)
      print_job_help
      ;;
    *)
      command_error "未知的 job 子命令: $action" print_job_help
      ;;
  esac
}
