#!/bin/zsh
# filepath: bin/lib/help_lint.sh

print_lint_check_help() {
  cat <<'EOF'
用法:
  macos-scripts lint check [路径 ...]

说明:
  对指定路径执行语法检查、shellcheck 和 shfmt 差异检查。
  未提供路径时默认检查整个仓库。
EOF
}

print_lint_fix_help() {
  cat <<'EOF'
用法:
  macos-scripts lint fix [路径 ...]

说明:
  对指定路径执行语法检查，并用 shfmt 自动修复格式。
  未提供路径时默认检查整个仓库。
EOF
}

print_lint_help() {
  cat <<'EOF'
用法:
  macos-scripts lint check [路径 ...]
  macos-scripts lint fix [路径 ...]

说明:
  check            执行语法检查、shellcheck 与 shfmt 差异检查
  fix              执行语法检查并用 shfmt 自动修复格式
EOF
}
