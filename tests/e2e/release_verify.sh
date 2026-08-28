#!/bin/bash
# filepath: tests/e2e/release_verify.sh
# E2E: release verify 真实流程。
# 验证版本一致性检查（VERSION + Formula）与 gh 命令桩的 verify-only 链路。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/e2e_lib.sh"

e2e_begin "release-verify"

cd "$REPO_ROOT"

e2e_run_expect_success \
  "release verify 版本一致通过" \
  zsh bin/macos-scripts release verify v0.4.0

e2e_assert_contains "$E2E_RUN_OUTPUT" "版本一致性检查通过" "release verify 输出一致性通过"
e2e_assert_contains "$E2E_RUN_OUTPUT" "verify-only 检查完成" "release verify 完成 verify-only 链路"
e2e_assert_transcript_contains \
  "gh api repos/anzihenry/scripts/releases/tags/v0.4.0" \
  "release verify 调用 gh api 检查 release 状态"

e2e_run_expect_failure \
  "release verify 版本不匹配失败" \
  zsh bin/macos-scripts release verify v9.9.9

e2e_assert_contains "$E2E_RUN_OUTPUT" "版本不一致" "release verify 提示版本不一致"

e2e_summary
