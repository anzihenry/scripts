#!/bin/bash
# filepath: tests/e2e/bootstrap_install.sh
# E2E: bootstrap/install.sh 真实流程（brew / curl / macos-scripts 命令桩）。
# 断言 tap + install 调用、日志文件写入与整体退出码。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/e2e_lib.sh"

e2e_begin "bootstrap-install"

cd "$REPO_ROOT"

e2e_run_expect_success \
  "bootstrap 真实安装流程" \
  zsh bootstrap/install.sh --yes --skip-configure

e2e_assert_transcript_contains \
  "brew tap anzihenry/scripts https://github.com/anzihenry/scripts" \
  "bootstrap 调用 brew tap"
e2e_assert_transcript_contains \
  "brew install anzihenry/scripts/macos-scripts" \
  "bootstrap 调用 brew install"
e2e_assert_contains "$E2E_RUN_OUTPUT" "Bootstrap 完成" "bootstrap 输出完成"
e2e_assert_file "$E2E_LOG_DIR/bootstrap.log" "bootstrap 写入日志文件"

e2e_summary
