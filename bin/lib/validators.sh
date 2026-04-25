#!/bin/zsh
# filepath: bin/lib/validators.sh

validate_setup_git_args() {
  local -a args=("$@")
  local index=1
  local arg

  while (( index <= $#args )); do
    arg="${args[index]}"
    case "$arg" in
      -d|--domain|-t|--type)
        (( index < $#args )) || {
          usage_error "$arg 需要一个参数值" print_setup_git_help
          return 1
        }
        (( index += 2 ))
        ;;
      --force|--skip-upload|--debug)
        (( index++ ))
        ;;
      -h|--help|help)
        return 0
        ;;
      *)
        usage_error "setup git 不支持参数: $arg" print_setup_git_help
        return 1
        ;;
    esac
  done
}

validate_setup_github_args() {
  local -a args=("$@")
  local index=1
  local arg

  while (( index <= $#args )); do
    arg="${args[index]}"
    case "$arg" in
      -t|--type)
        (( index < $#args )) || {
          usage_error "$arg 需要一个参数值" print_setup_github_help
          return 1
        }
        (( index += 2 ))
        ;;
      --force|--skip-upload|--debug)
        (( index++ ))
        ;;
      -d|--domain)
        usage_error "setup github 固定使用 github.com；如需自定义域名请改用 'macos-scripts setup git --domain <domain>'" print_setup_github_help
        return 1
        ;;
      -h|--help|help)
        return 0
        ;;
      *)
        usage_error "setup github 不支持参数: $arg" print_setup_github_help
        return 1
        ;;
    esac
  done
}

validate_maintain_brew_args() {
  local -a args=("$@")
  local arg

  for arg in "${args[@]}"; do
    case "$arg" in
      --dry-run|--yes|-y|--force|--skip-formulae|--skip-casks|--skip-cleanup|-h|--help|help)
        ;;
      *)
        usage_error "maintain brew 不支持参数: $arg" print_maintain_brew_help
        return 1
        ;;
    esac
  done
}

validate_installer_list_args() {
  local -a args=("$@")
  local arg

  for arg in "${args[@]}"; do
    case "$arg" in
      --verbose|-v|-h|--help|help)
        ;;
      *)
        usage_error "maintain installer list 不支持参数: $arg" print_maintain_installer_list_help
        return 1
        ;;
    esac
  done
}

validate_installer_download_args() {
  local -a args=("$@")
  local index=1
  local arg

  while (( index <= $#args )); do
    arg="${args[index]}"
    case "$arg" in
      --version)
        (( index < $#args )) || {
          usage_error "--version 需要一个参数值" print_maintain_installer_download_help
          return 1
        }
        (( index += 2 ))
        ;;
      --force|-f|--verbose|-v|-h|--help|help)
        (( index++ ))
        ;;
      *)
        usage_error "maintain installer download 不支持参数: $arg" print_maintain_installer_download_help
        return 1
        ;;
    esac
  done
}

validate_installer_create_args() {
  local -a args=("$@")
  local index=1
  local arg

  while (( index <= $#args )); do
    arg="${args[index]}"
    case "$arg" in
      --volume|--installer-path|--version)
        (( index < $#args )) || {
          usage_error "$arg 需要一个参数值" print_maintain_installer_create_help
          return 1
        }
        (( index += 2 ))
        ;;
      -y|--yes|--nointeraction|--force|-f|--verbose|-v|-h|--help|help)
        (( index++ ))
        ;;
      *)
        usage_error "maintain installer create 不支持参数: $arg" print_maintain_installer_create_help
        return 1
        ;;
    esac
  done
}

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

infer_release_notes_file() {
  local tag="$1"
  printf 'releases/%s-release-notes.md' "$tag"
}

normalize_release_tag() {
  local raw_tag="$1"

  if [[ "$raw_tag" == v* ]]; then
    printf '%s' "$raw_tag"
    return 0
  fi

  if [[ "$raw_tag" == V* ]]; then
    printf 'v%s' "${raw_tag#V}"
    return 0
  fi

  if [[ "$raw_tag" =~ '^[0-9]+([.][0-9]+){1,2}([.-][0-9A-Za-z.-]+)?$' ]]; then
    printf 'v%s' "$raw_tag"
    return 0
  fi

  printf '%s' "$raw_tag"
}

validate_release_publish_args() {
  local -a args=("$@")
  local index=1
  local arg
  local tag=""

  while (( index <= $#args )); do
    arg="${args[index]}"
    if [[ -z "$tag" && "$arg" != -* ]]; then
      tag="$arg"
      (( index++ ))
      continue
    fi

    case "$arg" in
      --notes-file|--target|--title|--repo)
        (( index < $#args )) || {
          usage_error "$arg 需要一个参数值" print_release_publish_help
          return 1
        }
        (( index += 2 ))
        ;;
      --yes|-y|--dry-run)
        (( index++ ))
        ;;
      -h|--help|help)
        return 0
        ;;
      *)
        usage_error "release publish 不支持参数: $arg" print_release_publish_help
        return 1
        ;;
    esac
  done

  [[ -n "$tag" ]] || {
    usage_error "release publish 需要提供版本 tag，例如 0.2.0 或 v0.2.0" print_release_publish_help
    return 1
  }
}

validate_release_verify_args() {
  local -a args=("$@")
  local index=1
  local arg
  local tag=""

  while (( index <= $#args )); do
    arg="${args[index]}"
    if [[ -z "$tag" && "$arg" != -* ]]; then
      tag="$arg"
      (( index++ ))
      continue
    fi

    case "$arg" in
      --notes-file|--target|--title|--repo)
        (( index < $#args )) || {
          usage_error "$arg 需要一个参数值" print_release_verify_help
          return 1
        }
        (( index += 2 ))
        ;;
      -h|--help|help)
        return 0
        ;;
      *)
        usage_error "release verify 不支持参数: $arg" print_release_verify_help
        return 1
        ;;
    esac
  done

  [[ -n "$tag" ]] || {
    usage_error "release verify 需要提供版本 tag，例如 0.2.0 或 v0.2.0" print_release_verify_help
    return 1
  }
}
