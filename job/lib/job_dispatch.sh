#!/bin/zsh

dispatch_create_action() {
    prepare_create_args
    execute_create "$JOB_NAME" "$TARGET_SCRIPT" "$INTERVAL" "$AT_TIME" "$WEEKDAY" "$KEEPALIVE" "$WORKING_DIR" "$STDOUT_PATH" "$STDERR_PATH" "$DISABLED" "$NO_LOAD" "$DRY_RUN" "${EXTRA_ARGS[@]}"
}

dispatch_delete_action() {
    validate_job_name "$JOB_NAME"
    execute_delete "$JOB_NAME" "$DRY_RUN"
}

dispatch_enable_action() {
    validate_job_name "$JOB_NAME"
    execute_enable "$JOB_NAME" "$DRY_RUN"
}

dispatch_disable_action() {
    validate_job_name "$JOB_NAME"
    execute_disable "$JOB_NAME" "$DRY_RUN"
}

dispatch_status_action() {
    validate_job_name "$JOB_NAME"
    show_status "$JOB_NAME"
}

dispatch_list_action() {
    list_jobs
}

dispatch_scheduler_action() {
    case "$ACTION" in
        create)
            dispatch_create_action
            ;;
        delete)
            dispatch_delete_action
            ;;
        enable)
            dispatch_enable_action
            ;;
        disable)
            dispatch_disable_action
            ;;
        status)
            dispatch_status_action
            ;;
        list)
            dispatch_list_action
            ;;
        *)
            error "未知动作: ${ACTION}"
            print_usage
            exit 1
            ;;
    esac
}
