#!/bin/zsh
# filepath: lint/lint_shell.sh
# 统一的 Shell 脚本 lint 工具
# 功能：
#   - 调用 shellcheck 进行静态分析
#   - 使用 shfmt 检查或格式化
# 用法：
#   lint/lint_shell.sh [--fix] [路径 ...]

set -e
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

FIX_MODE="false"
TARGETS=()
FILES=()
BASH_FILES=()
POSIX_FILES=()
ZSH_FILES=()
UNKNOWN_FILES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fix) FIX_MODE="true"; shift ;;
    -h|--help)
      cat <<'EOF'
用法: lint/lint_shell.sh [--fix] [路径 ...]
说明:
  --fix    使用 shfmt 自动格式化脚本
  未提供路径时默认检查整个仓库
示例:
  lint/lint_shell.sh
  lint/lint_shell.sh --fix setup
EOF
      exit 0
      ;;
    *)
      TARGETS+=("$1")
      shift
      ;;
  esac
done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  TARGETS=("$REPO_ROOT")
fi

collect_shell_files() {
  local base="$1"
  while IFS= read -r file; do
    FILES+=("$file")
  done < <(find "$base" -type f \( -name '*.sh' -o -path '*/bin/*' \) -not -path '*/.git/*' -not -path '*/vendor/*')
}

detect_shell() {
  local file="$1"
  local first_line

  IFS= read -r first_line < "$file" || true
  case "$first_line" in
    '#!'*zsh*) printf 'zsh' ;;
    '#!'*bash*) printf 'bash' ;;
    '#!'*'/sh'*) printf 'sh' ;;
    *) printf 'unknown' ;;
  esac
}

classify_files() {
  local file shell_name
  for file in "${FILES[@]}"; do
    shell_name="$(detect_shell "$file")"
    case "$shell_name" in
      zsh) ZSH_FILES+=("$file") ;;
      bash) BASH_FILES+=("$file") ;;
      sh) POSIX_FILES+=("$file") ;;
      *) UNKNOWN_FILES+=("$file") ;;
    esac
  done
}

run_syntax_checks() {
  local has_failures=0
  local file

  printf '语法检查: 按 shebang 执行 zsh -n / bash -n\n'

  for file in "${ZSH_FILES[@]}"; do
    zsh -n "$file" || has_failures=1
  done

  for file in "${BASH_FILES[@]}" "${POSIX_FILES[@]}" "${UNKNOWN_FILES[@]}"; do
    [[ -n "$file" ]] || continue
    bash -n "$file" || has_failures=1
  done

  [[ $has_failures -eq 0 ]]
}

run_shellcheck_group() {
  local shell_name="$1"
  shift
  [[ $# -gt 0 ]] || return 0
  shellcheck "${SC_OPTS[@]}" --shell="$shell_name" "$@"
}

run_shfmt_group() {
  local language="$1"
  shift
  [[ $# -gt 0 ]] || return 0

  if [[ "$FIX_MODE" == "true" ]]; then
    shfmt -ln "$language" "${SHFMT_OPTS[@]}" -w "$@"
  else
    shfmt -ln "$language" "${SHFMT_OPTS[@]}" -d "$@"
  fi
}

for target in "${TARGETS[@]}"; do
  if [[ -d "$target" ]]; then
    collect_shell_files "$target"
  elif [[ -f "$target" ]]; then
    FILES+=("$target")
  else
    printf '警告: 未找到目标 %s，已跳过\n' "$target" >&2
  fi
done

if [[ ${#FILES[@]} -eq 0 ]]; then
  printf '未找到需要检查的 Shell 文件。\n' >&2
  exit 0
fi

classify_files

if ! command -v shellcheck >/dev/null 2>&1; then
  printf '缺少 shellcheck，建议执行: brew install shellcheck\n' >&2
  exit 1
fi

if ! command -v shfmt >/dev/null 2>&1; then
  printf '缺少 shfmt，建议执行: brew install shfmt\n' >&2
  exit 1
fi

printf '共找到 %d 个 Shell 文件，开始检查...\n' "${#FILES[@]}"
printf '  zsh: %d, bash: %d, sh: %d, 未知: %d\n' "${#ZSH_FILES[@]}" "${#BASH_FILES[@]}" "${#POSIX_FILES[@]}" "${#UNKNOWN_FILES[@]}"

SC_OPTS=(--external-sources --severity=style --exclude=SC1071)
if [[ -n "${SHELLCHECK_OPTS:-}" ]]; then
  # shellcheck disable=SC2206 # 需要根据空格拆分额外参数
  SC_OPTS+=(${=SHELLCHECK_OPTS})
fi

if ! run_syntax_checks; then
  printf '语法检查失败，请先修复后再执行 lint。\n' >&2
  exit 1
fi

SHFMT_OPTS=(-i 2 -ci -bn -sr)
if [[ "$FIX_MODE" == "true" ]]; then
  printf 'shfmt: 自动格式化模式\n'
else
  printf 'shfmt: 差异检查模式\n'
fi

printf 'shellcheck: 按 shell 类型执行（zsh 文件仅做语法检查）\n'
run_shellcheck_group bash "${BASH_FILES[@]}"
run_shellcheck_group sh "${POSIX_FILES[@]}"

if [[ ${#UNKNOWN_FILES[@]} -gt 0 ]]; then
  printf '警告: 以下文件未识别 shebang，按 bash 进行 shellcheck/shfmt:\n' >&2
  printf '  %s\n' "${UNKNOWN_FILES[@]}" >&2
  run_shellcheck_group bash "${UNKNOWN_FILES[@]}"
fi

run_shfmt_group bash "${BASH_FILES[@]}"
run_shfmt_group posix "${POSIX_FILES[@]}"

if [[ ${#UNKNOWN_FILES[@]} -gt 0 ]]; then
  run_shfmt_group bash "${UNKNOWN_FILES[@]}"
fi

if [[ ${#ZSH_FILES[@]} -gt 0 ]]; then
  printf '提示: zsh 文件当前执行语法检查，但跳过 shfmt 与 shellcheck。\n'
fi

printf 'Shell lint 检查完成。\n'
