#!/bin/zsh
# filepath: bin/lib/cli_dispatch.sh

# shellcheck disable=SC1091
source "$REPO_ROOT/bin/lib/cli_dispatch_setup.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/bin/lib/cli_dispatch_maintain.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/bin/lib/cli_dispatch_release.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/bin/lib/cli_dispatch_job.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/bin/lib/cli_dispatch_lint.sh"

main() {
  local command="${1:-help}"
  shift || true

  case "$command" in
    setup)
      handle_setup "$@"
      ;;
    maintain)
      handle_maintain "$@"
      ;;
    release)
      handle_release "$@"
      ;;
    job)
      handle_job "$@"
      ;;
    lint)
      handle_lint "$@"
      ;;
    help|-h|--help)
      handle_help "$@"
      ;;
    version|--version|-v)
      printf 'macos-scripts v%s\n' "$MACOS_SCRIPTS_VERSION"
      ;;
    *)
      command_error "未知命令: $command" print_main_help
      ;;
  esac
}
