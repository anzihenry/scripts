#!/bin/zsh
# filepath: tests/syntax_guard.sh
# lint 入口统一维护文件发现、Zsh shebang 策略和语法检查。
set -euo pipefail
SCRIPT_DIR="${0:A:h}"
exec /bin/zsh "$SCRIPT_DIR/../lint/lint_shell.sh"
