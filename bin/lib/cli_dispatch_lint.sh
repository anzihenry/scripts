#!/bin/zsh
# filepath: bin/lib/cli_dispatch_lint.sh

handle_lint() {
  local action="${1:-check}"

  case "$action" in
    check)
      shift || true
      has_help_flag "$@" && { print_lint_check_help; return 0; }
      run_zsh_script "lint/lint_shell.sh" "$@"
      ;;
    fix)
      shift || true
      has_help_flag "$@" && { print_lint_fix_help; return 0; }
      run_zsh_script "lint/lint_shell.sh" --fix "$@"
      ;;
    help|-h|--help)
      print_lint_help
      ;;
    *)
      run_zsh_script "lint/lint_shell.sh" "$@"
      ;;
  esac
}
