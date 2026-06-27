#!/bin/zsh
# filepath: bin/lib/cli_dispatch_release.sh

handle_release_publish() {
  has_help_flag "$@" && { print_release_publish_help; return 0; }
  validate_release_publish_args "$@" || return 1

  local tag
  tag="$(normalize_release_tag "$1")"
  shift || true

  local notes_file=""
  local -a forwarded_args=(--tag "$tag" --update-existing)

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

  run_bash_script "maintain/github_release_publish.sh" "${forwarded_args[@]}"
}

handle_release_verify() {
  has_help_flag "$@" && { print_release_verify_help; return 0; }
  validate_release_verify_args "$@" || return 1

  local tag
  tag="$(normalize_release_tag "$1")"
  shift || true

  local notes_file=""
  local -a forwarded_args=(--tag "$tag" --verify-only)

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

  run_bash_script "maintain/github_release_publish.sh" "${forwarded_args[@]}"
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
