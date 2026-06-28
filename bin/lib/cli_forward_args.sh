#!/bin/zsh
# filepath: bin/lib/cli_forward_args.sh

# Keep forwarding glue separate from dispatch so command handlers can stay
# focused on help/validate/run orchestration.
build_setup_github_forwarded_args() {
  local has_domain="false"
  local has_type="false"
  local arg

  for arg in "$@"; do
    case "$arg" in
      -d|--domain) has_domain="true" ;;
      -t|--type) has_type="true" ;;
    esac
  done

  local -a forwarded_args=()
  [[ "$has_domain" == "false" ]] && forwarded_args+=(--domain github.com)
  [[ "$has_type" == "false" ]] && forwarded_args+=(--type personal)
  forwarded_args+=("$@")

  printf '%s\n' "${forwarded_args[@]}"
}

load_setup_github_forwarded_args() {
  local target_name="$1"
  shift
  load_forwarded_args "$target_name" build_setup_github_forwarded_args "$@"
}

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

load_release_forwarded_args() {
  local target_name="$1"
  local release_mode="$2"
  shift 2
  load_forwarded_args "$target_name" build_release_forwarded_args "$release_mode" "$@"
}
