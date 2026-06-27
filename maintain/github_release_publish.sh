#!/bin/bash
# filepath: maintain/github_release_publish.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$REPO_ROOT/lib/colors.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/lib/utils.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/release_publish_args.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/release_publish_flow.sh"

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

usage() {
  cat << EOF
用法:
  maintain/github_release_publish.sh --tag <vX.Y.Z> --notes-file <path> [选项]

说明:
  使用 gh CLI 非交互创建或更新 GitHub Release，避免依赖 VS Code UI。

必填参数:
  --tag <tag>               Git tag，例如 v0.2.0
  --notes-file <path>       Release note 文件路径

可选参数:
  --target <branch>         Release target，默认 main
  --title <title>           Release 标题，默认与 tag 相同
  --repo <owner/name>       GitHub 仓库，默认 anzihenry/scripts
  --yes                     跳过交互确认
  --dry-run                 仅打印将执行的动作
  --verify-only             仅检查 tag、gh 登录状态和现有 release 状态
  --update-existing         若 release 已存在则执行更新而不是报错
  -h, --help                显示帮助

示例:
  bash maintain/github_release_publish.sh \
    --tag v0.2.0 \
    --notes-file releases/v0.2.0-release-notes.md \
    --yes

  bash maintain/github_release_publish.sh \
    --tag v0.2.0 \
    --notes-file releases/v0.2.0-release-notes.md \
    --verify-only
EOF
}

main() {
  parse_release_publish_args "$@"
  check_release_prerequisites
  print_release_state || true

  if [[ "$VERIFY_ONLY" == "true" ]]; then
    success "verify-only 检查完成"
    exit 0
  fi

  if ! confirm_publish; then
    warning "已取消 GitHub Release 操作"
    exit 0
  fi

  create_or_update_release
  verify_release
}

main "$@"
