#!/bin/zsh
# filepath: bin/lib/cli_dispatch_release.sh

handle_release_publish() {
  has_help_flag "$@" && { print_release_publish_help; return 0; }
  validate_release_publish_args "$@" || return 1

  # 发布前强制校验版本一致性，防止以与 VERSION/Formula 不一致的 tag 发布
  local -a arg_list=("$@")
  local tag=""
  local arg
  for arg in "${arg_list[@]}"; do
    [[ "$arg" == -* ]] && continue
    tag="$(normalize_release_tag "$arg")"
    break
  done
  if [[ -n "$tag" ]]; then
    verify_release_version_consistency "$tag" || {
      error "版本一致性检查未通过，请先同步 VERSION 文件与 Formula 后重试"
      return 1
    }
  fi

  local -a forwarded_args=()
  load_release_forwarded_args forwarded_args publish "$@"
  run_release_script "${forwarded_args[@]}"
}

handle_release_verify() {
  has_help_flag "$@" && { print_release_verify_help; return 0; }
  validate_release_verify_args "$@" || return 1

  # verify 阶段输出版本一致性提示（不阻断，便于先了解差异）
  local -a arg_list=("$@")
  local tag=""
  local arg
  for arg in "${arg_list[@]}"; do
    [[ "$arg" == -* ]] && continue
    tag="$(normalize_release_tag "$arg")"
    break
  done
  if [[ -n "$tag" ]]; then
    verify_release_version_consistency "$tag" || true
  fi

  local -a forwarded_args=()
  load_release_forwarded_args forwarded_args verify "$@"
  run_release_script "${forwarded_args[@]}"
}

handle_release() {
  local action="${1:-help}"
  shift || true

  case "$action" in
    publish)
      handle_release_publish "$@"
      ;;
    verify)
      handle_release_verify "$@"
      ;;
    help|-h|--help)
      print_release_help
      ;;
    *)
      command_error "未知的 release 子命令: $action" print_release_help
      ;;
  esac
}
