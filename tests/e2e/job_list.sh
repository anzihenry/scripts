#!/bin/bash
# filepath: tests/e2e/job_list.sh
# E2E: job list 真实流程。
# 先通过 job create --no-load 在沙箱中写入 plist，再断言 job list 能发现该任务。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/e2e_lib.sh"

e2e_begin "job-list"

cd "$REPO_ROOT"

e2e_run_expect_success \
  "job create --no-load 写入 plist" \
  zsh bin/macos-scripts job create \
  --job-name list-demo \
  --script ./lint/lint_shell.sh \
  --interval 10 \
  --no-load

e2e_run_expect_success \
  "job list 列出任务" \
  zsh bin/macos-scripts job list

e2e_assert_contains "$E2E_RUN_OUTPUT" "list-demo" "job list 输出包含任务名"
e2e_assert_not_contains "$E2E_RUN_OUTPUT" "未找到任何" "job list 未提示空列表"

e2e_summary
