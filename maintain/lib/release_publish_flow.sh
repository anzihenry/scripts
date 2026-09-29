#!/bin/bash
# filepath: maintain/lib/release_publish_flow.sh

# 查询 release 状态，区分「确定不存在」(404) 与「查询失败」（网络/鉴权/限流）。
# 返回：0=存在，1=确定不存在，2=查询失败（未知状态）
# 旧实现把任意 gh 失败都当成「不存在」，会让 --verify-only 在断网时限流时
# 打印成功，也可能在状态未知时触发误创建。
release_status() {
  local stderr_file release_state
  stderr_file="$(mktemp "${TMPDIR:-/tmp}/release-status.XXXXXX")"

  # 注意：变量名不能用 status——zsh 中 status/pipestatus 是只读特殊变量。
  set +e
  env GH_PAGER=cat gh api "repos/$REPO_SLUG/releases/tags/$TAG" > /dev/null 2> "$stderr_file"
  release_state=$?
  set -e

  if [[ $release_state -eq 0 ]]; then
    rm -f "$stderr_file"
    return 0
  fi

  if grep -qE '(^|[^0-9])(404|HTTP 404|Not Found)' "$stderr_file" 2> /dev/null; then
    rm -f "$stderr_file"
    return 1
  fi

  warning "无法查询 Release 状态（gh 退出码 $release_state）：$(tr '\n' ' ' < "$stderr_file")"
  rm -f "$stderr_file"
  return 2
}

# 兼容旧调用方/测试：存在返回 0，不存在返回 1，查询失败同样返回 1。
release_exists() {
  local release_state=0
  release_status || release_state=$?
  [[ $release_state -eq 0 ]]
}

print_release_state() {
  local release_state=0
  release_status || release_state=$?

  if [[ $release_state -eq 2 ]]; then
    return 2
  fi

  if [[ $release_state -eq 0 ]]; then
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

  local release_state=0
  release_status || release_state=$?

  if [[ $release_state -eq 2 ]]; then
    error "无法确认 Release 是否已存在，为避免误操作已中止。请检查网络/gh 登录后重试。"
    exit 1
  fi

  if [[ $release_state -eq 0 ]]; then
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

  local release_state=0
  release_status || release_state=$?

  if [[ $release_state -eq 1 ]]; then
    error "发布后校验失败：未找到 Release $TAG"
    return 1
  fi

  if [[ $release_state -eq 2 ]]; then
    error "发布后无法查询 Release 状态（网络/鉴权问题），请手动确认: $TAG"
    return 1
  fi

  local release_url
  release_url="$(env GH_PAGER=cat gh api "repos/$REPO_SLUG/releases/tags/$TAG" --jq '.html_url')"
  success "Release 已就绪: $release_url"
}
