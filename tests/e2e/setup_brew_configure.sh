#!/bin/bash
# filepath: tests/e2e/setup_brew_configure.sh
# E2E: setup brew configure --dry-run 真实流程。
# 回归护栏：homebrew-setup.sh 必须完整 source config_writer.sh，
# 否则 dry-run 会在 write_managed_block 处报 command not found
# （v0.5.0 发布门禁首次抓到该缺陷）。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/e2e_lib.sh"

e2e_begin "setup-brew-configure"

cd "$REPO_ROOT"

e2e_run_expect_success \
  "setup brew configure dry-run" \
  zsh bin/macos-scripts setup brew configure --dry-run

e2e_assert_contains "$E2E_RUN_OUTPUT" "系统环境预检通过" "setup brew 预检通过"
e2e_assert_contains "$E2E_RUN_OUTPUT" "配置完成" "setup brew 输出配置完成"
e2e_assert_not_contains "$E2E_RUN_OUTPUT" "command not found" "未出现缺失函数错误"
e2e_assert_file "$E2E_LOG_DIR/homebrew-setup.log" "setup brew 写入日志文件"

e2e_summary
