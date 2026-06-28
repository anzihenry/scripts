#!/bin/zsh
# filepath: bin/lib/validators_maintain.sh

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
