#!/bin/bash
# filepath: tests/e2e/job_create.sh
# E2E: job create 真实流程。
# 在沙箱中真实写入 plist、经 plutil -lint 校验，并调用 launchctl 命令桩
# 完成 bootstrap/enable；断言产物文件与外部调用序列。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/e2e_lib.sh"

e2e_begin "job-create"

cd "$REPO_ROOT"

e2e_run_expect_success \
  "job create 真实创建" \
  zsh bin/macos-scripts job create \
  --job-name e2e-demo \
  --script ./lint/lint_shell.sh \
  --interval 5

PLIST="$E2E_LAUNCH_AGENTS_DIR/com.biucing.scripts.job.e2e-demo.plist"

e2e_assert_file "$PLIST" "plist 已写入沙箱 LaunchAgents"
e2e_assert_file_contains "$PLIST" "com.biucing.scripts.job.e2e-demo" "plist 包含 Label"
e2e_assert_file_contains "$PLIST" "<key>StartInterval</key>" "plist 包含 StartInterval"
e2e_assert_file_contains "$PLIST" "<integer>300</integer>" "interval=5 分钟转为 300 秒"
e2e_assert_file_contains "$PLIST" "lint_shell.sh" "plist 包含目标脚本"
e2e_assert_file_contains "$PLIST" "<key>WorkingDirectory</key>" "plist 包含 WorkingDirectory"

e2e_assert_contains "$E2E_RUN_OUTPUT" "plist 写入完成" "job create 输出 plist 写入完成"
e2e_assert_contains "$E2E_RUN_OUTPUT" "创建任务 e2e-demo" "job create 输出创建任务计时"

e2e_assert_transcript_contains \
  "launchctl bootstrap gui/501 $PLIST" \
  "job create 调用 launchctl bootstrap"
e2e_assert_transcript_contains \
  "launchctl enable gui/501/com.biucing.scripts.job.e2e-demo" \
  "job create 调用 launchctl enable"

e2e_assert_dir "$E2E_LOG_DIR/jobs" "job create 创建 jobs 日志目录"

e2e_summary
