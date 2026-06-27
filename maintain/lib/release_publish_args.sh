#!/bin/bash
# filepath: maintain/lib/release_publish_args.sh

parse_release_publish_args() {
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
      --yes | -y)
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
      -h | --help | help)
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

resolve_release_notes_file() {
  if [[ "$NOTES_FILE" == /* ]]; then
    printf '%s' "$NOTES_FILE"
  else
    printf '%s' "$REPO_ROOT/$NOTES_FILE"
  fi
}

check_release_prerequisites() {
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

  NOTES_FILE="$(resolve_release_notes_file)"
  [[ -f "$NOTES_FILE" ]] || {
    error "Release note 文件不存在: $NOTES_FILE"
    exit 1
  }

  if [[ -z "$TITLE" ]]; then
    TITLE="$TAG"
  fi

  git -C "$REPO_ROOT" rev-parse "$TAG" > /dev/null 2>&1 || {
    error "本地不存在 tag: $TAG"
    exit 1
  }

  git -C "$REPO_ROOT" ls-remote --tags origin "refs/tags/$TAG" | grep -q "refs/tags/$TAG$" || {
    error "远端 origin 不存在 tag: $TAG"
    exit 1
  }

  env GH_PAGER=cat gh auth status > /dev/null 2>&1 || {
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
