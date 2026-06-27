#!/bin/bash
# filepath: maintain/lib/release_publish_flow.sh

release_exists() {
  env GH_PAGER=cat gh api "repos/$REPO_SLUG/releases/tags/$TAG" > /dev/null 2>&1
}

print_release_state() {
  if release_exists; then
    local release_url
    release_url="$(env GH_PAGER=cat gh api "repos/$REPO_SLUG/releases/tags/$TAG" --jq '.html_url')"
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

    run_logged_command "更新 GitHub Release: $TAG" \
      gh release edit "$TAG" \
      --repo "$REPO_SLUG" \
      --title "$TITLE" \
      --notes-file "$NOTES_FILE"
  else
    run_logged_command "创建 GitHub Release: $TAG" \
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
  release_url="$(env GH_PAGER=cat gh api "repos/$REPO_SLUG/releases/tags/$TAG" --jq '.html_url')"
  success "Release 已就绪: $release_url"
}
