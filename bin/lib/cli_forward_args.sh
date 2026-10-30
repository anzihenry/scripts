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
