#!/bin/zsh
# 统一的 Shell 脚本 lint 工具
# 功能：
#   - 调用 shellcheck 进行静态分析
#   - 使用 shfmt 检查或格式化
# 用法：
#   scripts/lint_shell.sh [--fix] [路径 ...]

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

FIX_MODE="false"
TARGETS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fix) FIX_MODE="true"; shift ;;
    -h|--help)
      cat <<'EOF'
用法: scripts/lint_shell.sh [--fix] [路径 ...]
说明:
  --fix    使用 shfmt 自动格式化脚本
  未提供路径时默认检查整个仓库
示例:
  scripts/lint_shell.sh
  scripts/lint_shell.sh --fix setup
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
  done < <(find "$base" -type f -name '*.sh' -not -path '*/.git/*' -not -path '*/vendor/*')
}

FILES=()
for target in "${TARGETS[@]}"; do
  if [[ -d "$target" ]]; then
    collect_shell_files "$target"
  elif [[ -f "$target" ]]; then
    [[ "$target" == *.sh ]] && FILES+=("$target")
  else
    printf '警告: 未找到目标 %s，已跳过\n' "$target" >&2
  fi
done

if [[ ${#FILES[@]} -eq 0 ]]; then
  printf '未找到需要检查的 Shell 文件。\n' >&2
  exit 0
fi

if ! command -v shellcheck >/dev/null 2>&1; then
  printf '缺少 shellcheck，建议执行: brew install shellcheck\n' >&2
  exit 1
fi

if ! command -v shfmt >/dev/null 2>&1; then
  printf '缺少 shfmt，建议执行: brew install shfmt\n' >&2
  exit 1
fi

printf '共找到 %d 个 Shell 文件，开始检查...\n' "${#FILES[@]}"

SC_OPTS=(--external-sources --severity=style --exclude=SC1071)
if [[ -n "${SHELLCHECK_OPTS:-}" ]]; then
  # shellcheck disable=SC2206 # 需要根据空格拆分额外参数
  SC_OPTS+=(${=SHELLCHECK_OPTS})
fi

shellcheck "${SC_OPTS[@]}" "${FILES[@]}"

SHFMT_OPTS=(-i 2 -ci -bn -sr)
if [[ "$FIX_MODE" == "true" ]]; then
  printf 'shfmt: 自动格式化模式\n'
  shfmt "${SHFMT_OPTS[@]}" -w "${FILES[@]}"
else
  printf 'shfmt: 差异检查模式\n'
  shfmt "${SHFMT_OPTS[@]}" -d "${FILES[@]}"
fi

printf 'Shell lint 检查完成。\n'
