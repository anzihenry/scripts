#!/bin/bash
# filepath: tests/e2e/maintain_brew.sh
# E2E: maintain brew 真实流程（brew 命令桩）。
# 成功路径断言 brew 调用顺序；失败路径断言错误日志写入与退出码。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/e2e_lib.sh"

e2e_begin "maintain-brew"

cd "$REPO_ROOT"

# 成功路径
e2e_run_expect_success \
  "maintain brew 真实执行（成功路径）" \
  zsh bin/macos-scripts maintain brew --yes

e2e_assert_contains "$E2E_RUN_OUTPUT" "Homebrew 维护完成" "输出维护完成"
e2e_assert_transcript_order \
  "brew 调用顺序正确" \
  "brew update" \
  "brew upgrade --formula" \
  "brew outdated --cask --greedy" \
  "brew info --cask rectangle" \
  "brew upgrade --cask rectangle" \
  "brew cleanup"
e2e_assert_not_file "$E2E_LOG_DIR/brew_update_errors.log" "成功路径未写入错误日志"

# 失败路径：Cask 失效 -> 记录错误日志并返回非零
e2e_run_expect_failure \
  "maintain brew cask 失败路径" \
  env E2E_BREW_OUTDATED_CASKS="broken-app 1.0.0" E2E_BREW_FAIL_CASK="broken-app" \
  zsh bin/macos-scripts maintain brew --yes

e2e_assert_contains "$E2E_RUN_OUTPUT" "Cask 不存在或已失效" "失败路径输出错误信息"
e2e_assert_file_contains "$E2E_LOG_DIR/brew_update_errors.log" "broken-app" "错误日志记录失败 cask"

e2e_summary
