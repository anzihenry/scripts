#!/bin/bash
# filepath: maintain/lib/release_publish_context.sh

# 本文件是被 source 的共享状态模块：变量在此初始化，
# 由 release_publish_args.sh 赋值、release_publish_flow.sh 消费。
# 静态分析无法跨文件追踪这些变量（在本文件看似未使用），
# 因此文件级禁用 SC2034 以消除误报。
# shellcheck disable=SC2034
initialize_release_publish_context() {
  RELEASE_LOG_FILE="$(prepare_log_file_path "github-release-publish.log" "$SCRIPT_DIR/github-release-publish.log")"
  enable_log_capture "$RELEASE_LOG_FILE"

  REPO_SLUG="anzihenry/scripts"
  TAG=""
  TARGET="main"
  TITLE=""
  NOTES_FILE=""
  YES="false"
  DRY_RUN="false"
  VERIFY_ONLY="false"
  UPDATE_EXISTING="false"
}
