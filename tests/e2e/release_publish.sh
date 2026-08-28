#!/bin/bash
# filepath: tests/e2e/release_publish.sh
# E2E: release publish 真实流程（gh 命令桩）。
# 覆盖 dry-run（打印不执行）、创建路径、更新路径三类关键分支。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/e2e_lib.sh"

e2e_begin "release-publish"

cd "$REPO_ROOT"

NOTES_FILE="$E2E_TMP_ROOT/notes.md"
printf 'Release notes stub\n' > "$NOTES_FILE"

# 1) dry-run：应打印将执行的命令，但不实际调用 gh release create
e2e_run_expect_success \
  "release publish dry-run" \
  zsh bin/macos-scripts release publish v0.4.0 --dry-run --notes-file "$NOTES_FILE"

e2e_assert_contains "$E2E_RUN_OUTPUT" "dry-run 模式未实际创建 release" "dry-run 输出未实际创建"
e2e_assert_contains "$E2E_RUN_OUTPUT" "gh release create v0.4.0" "dry-run 打印将执行的 gh 命令"
e2e_assert_transcript_not_contains "gh release create" "dry-run 未实际调用 gh release create"

# 2) 真实发布：创建路径（release 尚不存在）
e2e_run_expect_success \
  "release publish 真实创建" \
  zsh bin/macos-scripts release publish v0.4.0 --yes --notes-file "$NOTES_FILE"

e2e_assert_transcript_contains \
  "gh release create v0.4.0 --repo anzihenry/scripts --title v0.4.0 --target main --notes-file $NOTES_FILE" \
  "gh release create 调用参数正确"
e2e_assert_transcript_order \
  "gh 调用顺序: api 检查 -> release create" \
  "gh api repos/anzihenry/scripts/releases/tags/v0.4.0" \
  "gh release create"
e2e_assert_contains "$E2E_RUN_OUTPUT" "Release 已就绪" "发布结果校验输出"
e2e_assert_file "$E2E_LOG_DIR/github-release-publish.log" "发布日志写入沙箱日志目录"

# 3) 再次发布：更新路径（release 已存在，CLI 默认带 --update-existing）
e2e_run_expect_success \
  "release publish 更新已存在" \
  zsh bin/macos-scripts release publish v0.4.0 --yes --notes-file "$NOTES_FILE"

e2e_assert_transcript_contains \
  "gh release edit v0.4.0 --repo anzihenry/scripts --title v0.4.0 --notes-file $NOTES_FILE" \
  "gh release edit 更新调用参数正确"

e2e_summary
