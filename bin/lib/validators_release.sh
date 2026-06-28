#!/bin/zsh
# filepath: bin/lib/validators_release.sh

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
    usage_error "release publish 需要提供版本 tag，例如 0.3.0 或 v0.3.0" print_release_publish_help
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
    usage_error "release verify 需要提供版本 tag，例如 0.3.0 或 v0.3.0" print_release_verify_help
    return 1
  }
}
