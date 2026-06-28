#!/bin/zsh
# filepath: bin/lib/cli_dispatch_release.sh

build_release_forwarded_args() {
  local release_mode="$1"
  shift

  local tag
  tag="$(normalize_release_tag "$1")"
  shift || true

  local notes_file=""
  local default_flag=""
  case "$release_mode" in
    publish) default_flag="--update-existing" ;;
    verify) default_flag="--verify-only" ;;
    *)
      command_error "未知的 release 模式: $release_mode" print_release_help
      return 1
      ;;
  esac

  local -a forwarded_args=(--tag "$tag" "$default_flag")

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --notes-file)
        notes_file="$2"
        forwarded_args+=("$1" "$2")
        shift 2
        ;;
      *)
        forwarded_args+=("$1")
        shift
        ;;
    esac
  done

  if [[ -z "$notes_file" ]]; then
    forwarded_args+=(--notes-file "$(infer_release_notes_file "$tag")")
  fi

  printf '%s\n' "${forwarded_args[@]}"
}

handle_release_publish() {
  has_help_flag "$@" && { print_release_publish_help; return 0; }
  validate_release_publish_args "$@" || return 1

  local -a forwarded_args=()
  load_forwarded_args forwarded_args build_release_forwarded_args publish "$@"
  run_release_script "${forwarded_args[@]}"
}

handle_release_verify() {
  has_help_flag "$@" && { print_release_verify_help; return 0; }
  validate_release_verify_args "$@" || return 1

  local -a forwarded_args=()
  load_forwarded_args forwarded_args build_release_forwarded_args verify "$@"
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
