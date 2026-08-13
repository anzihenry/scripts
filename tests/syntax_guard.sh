#!/bin/bash
# filepath: tests/syntax_guard.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS_COUNT=0
SKIP_COUNT=0

pass() {
  printf '[PASS] %s\n' "$1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

skip() {
  printf '[SKIP] %s\n' "$1"
  SKIP_COUNT=$((SKIP_COUNT + 1))
}

detect_shell() {
  local file="$1"
  local first_line=""

  IFS= read -r first_line < "$file" || true
  case "$first_line" in
    '#!'*zsh*) printf 'zsh' ;;
    '#!'*bash*) printf 'bash' ;;
    '#!'*'/sh'*) printf 'bash' ;;
    *) printf 'unknown' ;;
  esac
}

run_syntax_check() {
  local file="$1"
  local shell_name="$2"

  case "$shell_name" in
    zsh)
      zsh -n "$file"
      pass "zsh -n ${file}"
      ;;
    bash)
      bash -n "$file"
      pass "bash -n ${file}"
      ;;
    *)
      skip "未识别 shebang: ${file}"
      ;;
  esac
}

main() {
  cd "$REPO_ROOT"

  local files=()
  while IFS= read -r file; do
    files+=("$file")
  done < <(find bin setup maintain job lint lib tests -type f)

  if [[ ${#files[@]} -eq 0 ]]; then
    printf '未找到需要检查的脚本文件。\n' >&2
    exit 1
  fi

  local file shell_name
  for file in "${files[@]}"; do
    [[ -f "$file" ]] || continue
    shell_name="$(detect_shell "$file")"
    [[ "$shell_name" == "unknown" ]] && continue
    run_syntax_check "$file" "$shell_name"
  done

  printf '\nSyntax checks passed: %d, skipped: %d\n' "$PASS_COUNT" "$SKIP_COUNT"
}

main "$@"
