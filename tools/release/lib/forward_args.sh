#!/bin/zsh
# filepath: tools/release/lib/forward_args.sh
build_release_forwarded_args() {
  local release_mode="$1"
  shift

  local tag="" notes_file=""
  local -a options=()
  # 参数校验允许选项放在 tag 前；成对消费选项，不能把标题当成 tag。
  while (( $# > 0 )); do
    case "$1" in
      --notes-file|--target|--title|--repo)
        [[ "$1" != --notes-file ]] || notes_file="$2"
        options+=("$1" "$2")
        shift 2
        ;;
      -*) options+=("$1"); shift ;;
      *) tag="$(normalize_release_tag "$1")"; shift ;;
    esac
  done

  local default_flag=""
  case "$release_mode" in
    publish) default_flag="--update-existing" ;;
    verify) default_flag="--verify-only" ;;
    *)
      command_error "未知的 release 模式: $release_mode" print_release_help
      return 1
      ;;
  esac

  local -a forwarded_args=(--tag "$tag" "$default_flag" "${options[@]}")

  if [[ -z "$notes_file" ]]; then
    forwarded_args+=(--notes-file "$(infer_release_notes_file "$tag")")
  fi

  printf '%s\n' "${forwarded_args[@]}"
}

load_release_forwarded_args() {
  local target_name="$1"
  local release_mode="$2"
  shift 2
  load_forwarded_args "$target_name" build_release_forwarded_args "$release_mode" "$@"
}
