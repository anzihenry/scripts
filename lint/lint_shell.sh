#!/bin/zsh
# filepath: lint/lint_shell.sh
# 仓库统一使用系统 Zsh；ShellCheck/shfmt 不支持 Zsh，不能作为检查器。
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h}"
TARGETS=()
FILES=()
FIX_MODE=false

while (( $# > 0 )); do
  case "$1" in
    --fix) FIX_MODE=true; shift ;;
    -h|--help)
      cat <<'HELP'
用法: lint/lint_shell.sh [--fix] [路径 ...]
说明:
  检查 #!/bin/zsh shebang 和 Zsh 语法，默认检查整个仓库。
  --fix 为兼容参数：仍执行检查，不自动修改 Zsh 格式。
  ShellCheck 与 shfmt 不支持 Zsh；运行时行为请使用 guard / E2E 验证。
HELP
      exit 0
      ;;
    *) TARGETS+=("$1"); shift ;;
  esac
done

source "$REPO_ROOT/lib/utils.sh"
require_supported_macos || exit 1

(( ${#TARGETS[@]} > 0 )) || TARGETS=("$REPO_ROOT")
for target in "${TARGETS[@]}"; do
  if [[ -d "$target" ]]; then
    while IFS= read -r -d '' file; do
      FILES+=("$file")
    done < <(find "$target" -type f \( -name '*.sh' -o -path '*/bin/*' -o -path '*/tests/e2e/shims/*' \) \
      -not -path '*/.git/*' -not -path '*/vendor/*' -print0)
  elif [[ -f "$target" ]]; then
    FILES+=("$target")
  else
    printf '未找到目标: %s\n' "$target" >&2
    exit 1
  fi
done

(( ${#FILES[@]} > 0 )) || { printf '未找到 Shell 文件。\n' >&2; exit 1; }
[[ "$FIX_MODE" == false ]] || printf '提示: Zsh 暂无自动格式化；--fix 本次仅执行检查。\n' >&2

has_failures=0
for file in "${FILES[@]}"; do
  first_line=""
  IFS= read -r first_line < "$file" || true
  if [[ "$first_line" != '#!/bin/zsh' ]]; then
    printf 'shebang 必须为 #!/bin/zsh: %s\n' "$file" >&2
    has_failures=1
    continue
  fi
  /bin/zsh -n "$file" || has_failures=1
done
(( has_failures == 0 )) || exit 1
printf 'Zsh shebang 与语法检查通过: %d 个文件。\n' "${#FILES[@]}"
