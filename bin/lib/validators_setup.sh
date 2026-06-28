#!/bin/zsh
# filepath: bin/lib/validators_setup.sh

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
