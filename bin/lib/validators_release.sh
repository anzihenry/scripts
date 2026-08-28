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
    usage_error "release publish 需要提供版本 tag，例如 0.5.0 或 v0.5.0" print_release_publish_help
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
    usage_error "release verify 需要提供版本 tag，例如 0.5.0 或 v0.5.0" print_release_verify_help
    return 1
  }
}

# ===== 版本一致性校验 =====
# 读取 VERSION 权威文件与 Formula 引用版本，与目标 tag 对比。
# 返回 0 表示一致；返回 1 表示存在不一致（调用方决定阻断策略）。
read_version_authority() {
  if [[ -r "$REPO_ROOT/VERSION" ]]; then
    printf '%s' "$(<"$REPO_ROOT/VERSION")"
    return 0
  fi
  return 1
}

read_formula_referenced_version() {
  local formula_file="$REPO_ROOT/Formula/macos-scripts.rb"
  [[ -f "$formula_file" ]] || return 1
  grep -oE 'refs/tags/v[0-9]+\.[0-9]+\.[0-9]+' "$formula_file" | head -1 | sed 's#refs/tags/v##'
}

verify_release_version_consistency() {
  local tag="$1"
  local expected_version=""
  local formula_version=""
  local has_mismatch=false

  expected_version="$(read_version_authority || true)"
  formula_version="$(read_formula_referenced_version || true)"
  local tag_version="${tag#v}"

  if [[ -z "$expected_version" ]]; then
    warning "未找到 VERSION 权威文件（$REPO_ROOT/VERSION），跳过版本一致性检查"
  elif [[ "$tag_version" != "$expected_version" ]]; then
    warning "版本不一致: tag=$tag，VERSION 文件=$expected_version"
    has_mismatch=true
  fi

  if [[ -n "$formula_version" && "$tag_version" != "$formula_version" ]]; then
    warning "版本不一致: tag=$tag，Formula 引用=$formula_version"
    has_mismatch=true
  fi

  if [[ "$has_mismatch" == "false" ]]; then
    success "版本一致性检查通过: $tag"
  fi

  [[ "$has_mismatch" == "false" ]]
}
