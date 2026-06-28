#!/bin/zsh
# filepath: bin/lib/validators_job.sh

validate_job_name_value() {
  local value="$1"
  [[ -n "$value" ]] || return 1
  [[ "$value" =~ ^[A-Za-z0-9._-]+$ ]]
}

validate_job_list_args() {
  local -a args=("$@")
  local arg

  for arg in "${args[@]}"; do
    case "$arg" in
      -h|--help|help)
        ;;
      *)
        usage_error "job list 不支持参数: $arg" print_job_list_help
        return 1
        ;;
    esac
  done
}

validate_job_name_action_args() {
  local action="$1"
  local help_func="$2"
  local allow_dry_run="$3"
  shift 3

  local -a args=("$@")
  local index=1
  local arg
  local job_name=""

  while (( index <= $#args )); do
    arg="${args[index]}"
    case "$arg" in
      --job-name)
        (( index < $#args )) || {
          usage_error "--job-name 需要一个参数值" "$help_func"
          return 1
        }
        job_name="${args[index + 1]}"
        (( index += 2 ))
        ;;
      --dry-run)
        if [[ "$allow_dry_run" != "true" ]]; then
          usage_error "job ${action} 不支持参数: --dry-run" "$help_func"
          return 1
        fi
        (( index++ ))
        ;;
      -h|--help|help)
        return 0
        ;;
      *)
        usage_error "job ${action} 不支持参数: $arg" "$help_func"
        return 1
        ;;
    esac
  done

  [[ -n "$job_name" ]] || {
    usage_error "job ${action} 需要提供 --job-name" "$help_func"
    return 1
  }
  validate_job_name_value "$job_name" || {
    usage_error "--job-name 仅支持字母、数字、点、下划线和短横" "$help_func"
    return 1
  }
}

validate_job_create_args() {
  local -a args=("$@")
  local index=1
  local arg
  local job_name=""
  local script_path=""
  local interval=""
  local at_time=""
  local weekday=""

  while (( index <= $#args )); do
    arg="${args[index]}"
    case "$arg" in
      --job-name|--script|--interval|--at|--weekday|--working-dir|--stdout|--stderr)
        (( index < $#args )) || {
          usage_error "$arg 需要一个参数值" print_job_create_help
          return 1
        }
        case "$arg" in
          --job-name) job_name="${args[index + 1]}" ;;
          --script) script_path="${args[index + 1]}" ;;
          --interval) interval="${args[index + 1]}" ;;
          --at) at_time="${args[index + 1]}" ;;
          --weekday) weekday="${args[index + 1]}" ;;
        esac
        (( index += 2 ))
        ;;
      --keepalive|--no-load|--disabled|--force|--dry-run)
        (( index++ ))
        ;;
      --)
        break
        ;;
      -h|--help|help)
        return 0
        ;;
      *)
        usage_error "job create 不支持参数: $arg" print_job_create_help
        return 1
        ;;
    esac
  done

  [[ -n "$job_name" ]] || {
    usage_error "job create 需要提供 --job-name" print_job_create_help
    return 1
  }
  validate_job_name_value "$job_name" || {
    usage_error "--job-name 仅支持字母、数字、点、下划线和短横" print_job_create_help
    return 1
  }
  [[ -n "$script_path" ]] || {
    usage_error "job create 需要提供 --script" print_job_create_help
    return 1
  }
  [[ -n "$interval" || -n "$at_time" ]] || {
    usage_error "job create 需要提供 --interval 或 --at" print_job_create_help
    return 1
  }
  [[ -z "$interval" || "$interval" =~ ^[0-9]+$ ]] || {
    usage_error "--interval 需要正整数" print_job_create_help
    return 1
  }
  [[ -z "$at_time" || "$at_time" =~ ^[0-2][0-9]:[0-5][0-9]$ ]] || {
    usage_error "--at 格式必须为 HH:MM" print_job_create_help
    return 1
  }
  [[ -z "$weekday" || "$weekday" =~ ^[0-6]$ ]] || {
    usage_error "--weekday 取值范围为 0-6" print_job_create_help
    return 1
  }
  [[ -z "$weekday" || -n "$at_time" ]] || {
    usage_error "--weekday 需要配合 --at 使用" print_job_create_help
    return 1
  }
}
