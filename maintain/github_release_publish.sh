#!/bin/bash
# filepath: maintain/github_release_publish.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -n "${MACOS_SCRIPTS_LOG_DIR:-}" ]]; then
  mkdir -p "$MACOS_SCRIPTS_LOG_DIR"
  RELEASE_LOG_FILE="$MACOS_SCRIPTS_LOG_DIR/github-release-publish.log"
else
  RELEASE_LOG_FILE="$SCRIPT_DIR/github-release-publish.log"
fi

exec > >(tee -a "$RELEASE_LOG_FILE") 2>&1

# shellcheck disable=SC1091
source "$REPO_ROOT/lib/colors.sh"

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
  cat <<EOF
用法:
  maintain/github_release_publish.sh --tag <vX.Y.Z> --notes-file <path> [选项]

说明:
  使用 gh CLI 非交互创建或更新 GitHub Release，避免依赖 VS Code UI。

必填参数:
  --tag <tag>               Git tag，例如 v0.1.0
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
    --tag v0.1.0 \
    --notes-file releases/v0.1.0-release-notes.md \
    --yes

  bash maintain/github_release_publish.sh \
    --tag v0.1.0 \
    --notes-file releases/v0.1.0-release-notes.md \
    --verify-only
EOF
}

run_command() {
  local description="$1"
  shift

  if [[ "$DRY_RUN" == "true" ]]; then
    info "[dry-run] $description"
    print_code "$*"
    return 0
  fi

  info "$description"
  "$@"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tag)
        TAG="${2:-}"
        shift 2
        ;;
      --notes-file)
        NOTES_FILE="${2:-}"
        shift 2
        ;;
      --target)
        TARGET="${2:-}"
        shift 2
        ;;
      --title)
        TITLE="${2:-}"
        shift 2
        ;;
      --repo)
        REPO_SLUG="${2:-}"
        shift 2
        ;;
      --yes|-y)
        YES="true"
        shift
        ;;
      --dry-run)
        DRY_RUN="true"
        shift
        ;;
      --verify-only)
        VERIFY_ONLY="true"
        shift
        ;;
      --update-existing)
        UPDATE_EXISTING="true"
        shift
        ;;
      -h|--help|help)
        usage
        exit 0
        ;;
      *)
        error "未知参数: $1"
        echo
        usage
        exit 1
        ;;
    esac
  done
}

require_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || {
    error "缺少依赖: $cmd"
    exit 1
  }
}

resolve_notes_file() {
  if [[ "$NOTES_FILE" == /* ]]; then
    printf '%s' "$NOTES_FILE"
  else
    printf '%s' "$REPO_ROOT/$NOTES_FILE"
  fi
}

check_prerequisites() {
  print_header "发布前检查"

  require_command git
  require_command gh

  [[ -n "$TAG" ]] || {
    error "必须提供 --tag"
    exit 1
  }

  [[ -n "$NOTES_FILE" ]] || {
    error "必须提供 --notes-file"
    exit 1
  }

  NOTES_FILE="$(resolve_notes_file)"
  [[ -f "$NOTES_FILE" ]] || {
    error "Release note 文件不存在: $NOTES_FILE"
    exit 1
  }

  if [[ -z "$TITLE" ]]; then
    TITLE="$TAG"
  fi

  git -C "$REPO_ROOT" rev-parse "$TAG" >/dev/null 2>&1 || {
    error "本地不存在 tag: $TAG"
    exit 1
  }

  git -C "$REPO_ROOT" ls-remote --tags origin "refs/tags/$TAG" | grep -q "refs/tags/$TAG$" || {
    error "远端 origin 不存在 tag: $TAG"
    exit 1
  }

  GH_PAGER=cat gh auth status >/dev/null 2>&1 || {
    error "gh 未登录，请先执行 gh auth login"
    exit 1
  }

  info "仓库: $REPO_SLUG"
  info "Tag: $TAG"
  info "Target: $TARGET"
  info "Title: $TITLE"
  info "Release note: $NOTES_FILE"
  info "日志文件位置: $RELEASE_LOG_FILE"
}

release_exists() {
  GH_PAGER=cat gh api "repos/$REPO_SLUG/releases/tags/$TAG" >/dev/null 2>&1
}

print_release_state() {
  if release_exists; then
    local release_url
    release_url="$(GH_PAGER=cat gh api "repos/$REPO_SLUG/releases/tags/$TAG" --jq '.html_url')"
    success "GitHub Release 已存在: $release_url"
    return 0
  fi

  warning "GitHub Release 尚不存在: $TAG"
  return 1
}

confirm_publish() {
  if [[ "$YES" == "true" || "$DRY_RUN" == "true" || "$VERIFY_ONLY" == "true" ]]; then
    return 0
  fi

  printf '%s' "将对 $REPO_SLUG 执行 GitHub Release 操作，是否继续 (y/N): "
  local reply=""
  read -r reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

create_or_update_release() {
  print_header "执行 GitHub Release"

  if release_exists; then
    if [[ "$UPDATE_EXISTING" != "true" ]]; then
      error "Release 已存在。如需更新，请追加 --update-existing。"
      exit 1
    fi

    run_command "更新 GitHub Release: $TAG" \
      gh release edit "$TAG" \
      --repo "$REPO_SLUG" \
      --title "$TITLE" \
      --notes-file "$NOTES_FILE"
  else
    run_command "创建 GitHub Release: $TAG" \
      gh release create "$TAG" \
      --repo "$REPO_SLUG" \
      --title "$TITLE" \
      --target "$TARGET" \
      --notes-file "$NOTES_FILE"
  fi
}

verify_release() {
  print_header "发布结果"

  if [[ "$DRY_RUN" == "true" ]]; then
    info "dry-run 模式未实际创建 release"
    return 0
  fi

  local release_url
  release_url="$(GH_PAGER=cat gh api "repos/$REPO_SLUG/releases/tags/$TAG" --jq '.html_url')"
  success "Release 已就绪: $release_url"
}

main() {
  parse_args "$@"
  check_prerequisites
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