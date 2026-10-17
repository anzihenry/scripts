#!/bin/zsh
# filepath: bin/lib/help_lint.sh

print_lint_check_help() {
  cat <<'EOF'
用法:
  macos-scripts lint check [路径 ...]

说明:
  对指定路径校验 #!/bin/zsh 并执行 Zsh 语法检查。
  未提供路径时默认检查整个仓库。
EOF
}

print_lint_fix_help() {
  cat <<'EOF'
用法:
  macos-scripts lint fix [路径 ...]

说明:
  兼容入口：执行 Zsh shebang 与语法检查，并提示不自动修改格式。
  未提供路径时默认检查整个仓库。
EOF
}

print_lint_help() {
  cat <<'EOF'
用法:
  macos-scripts lint check [路径 ...]
  macos-scripts lint fix [路径 ...]

说明:
  check            执行 Zsh shebang 与语法检查
  fix              兼容入口，仅检查，不自动修改 Zsh 格式
EOF
}
