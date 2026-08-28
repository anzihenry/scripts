#!/bin/bash
# filepath: tests/e2e/job_disable.sh
# E2E: job disable 真实流程。
# 断言 launchctl 命令桩被调用（disable），且输出任务已禁用。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/e2e_lib.sh"

e2e_begin "job-disable"

cd "$REPO_ROOT"

e2e_run_expect_success \
  "job create --no-load 写入 plist" \
  zsh bin/macos-scripts job create \
  --job-name disable-demo \
  --script ./lint/lint_shell.sh \
  --interval 10 \
  --no-load

e2e_run_expect_success \
  "job disable 禁用任务" \
  zsh bin/macos-scripts job disable --job-name disable-demo

e2e_assert_transcript_contains \
  "launchctl disable gui/501/com.biucing.scripts.job.disable-demo" \
  "job disable 调用 launchctl disable"
e2e_assert_contains "$E2E_RUN_OUTPUT" "任务已禁用" "job disable 输出任务已禁用"

e2e_summary
