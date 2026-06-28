#!/bin/zsh
# filepath: bin/lib/cli_dispatch_job.sh

validate_job_list_dispatch_args() {
  validate_job_list_args "$@"
}

validate_job_status_dispatch_args() {
  validate_job_name_action_args status print_job_status_help false "$@"
}

validate_job_create_dispatch_args() {
  validate_job_create_args "$@"
}

validate_job_enable_dispatch_args() {
  validate_job_name_action_args enable print_job_enable_help true "$@"
}

validate_job_disable_dispatch_args() {
  validate_job_name_action_args disable print_job_disable_help true "$@"
}

validate_job_delete_dispatch_args() {
  validate_job_name_action_args delete print_job_delete_help true "$@"
}

handle_job() {
  local action="${1:-help}"
  shift || true

  case "$action" in
    list)
      dispatch_validated_action has_help_flag print_job_list_help validate_job_list_dispatch_args run_scheduler_action list "$@"
      ;;
    status)
      dispatch_validated_action has_help_flag print_job_status_help validate_job_status_dispatch_args run_scheduler_action status "$@"
      ;;
    create)
      dispatch_validated_action has_help_flag_before_separator print_job_create_help validate_job_create_dispatch_args run_scheduler_action create "$@"
      ;;
    enable)
      dispatch_validated_action has_help_flag print_job_enable_help validate_job_enable_dispatch_args run_scheduler_action enable "$@"
      ;;
    disable)
      dispatch_validated_action has_help_flag print_job_disable_help validate_job_disable_dispatch_args run_scheduler_action disable "$@"
      ;;
    delete)
      dispatch_validated_action has_help_flag print_job_delete_help validate_job_delete_dispatch_args run_scheduler_action delete "$@"
      ;;
    help|-h|--help)
      print_job_help
      ;;
    *)
      command_error "未知的 job 子命令: $action" print_job_help
      ;;
  esac
}
