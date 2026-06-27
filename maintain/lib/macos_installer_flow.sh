#!/bin/zsh
# filepath: maintain/lib/macos_installer_flow.sh

acquire_installer_lock() {
  local key="$(sanitize_key "$1")"
  LOCK_DIR="/tmp/${SCRIPT_NAME}.${key}.lock"
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    trap 'rm -rf "$LOCK_DIR"' EXIT INT TERM HUP
    log_debug "已获取锁: $LOCK_DIR"
  else
    die "另一个相同操作正在进行中（锁: $LOCK_DIR）。稍后重试。"
  fi
}

resolve_existing_installer_for_download() {
  find_installer_app "$DOWNLOAD_VERSION" || true
}

should_skip_installer_download() {
  local existing="$1"
  [[ -n "$existing" && "$DOWNLOAD_FORCE" != "yes" ]]
}

verify_downloaded_installer() {
  local after="" after_ver=""
  after="$(find_installer_app "$DOWNLOAD_VERSION" || true)"
  [ -n "$after" ] && after_ver="$(get_installer_short_ver "$after")"
  if [ -n "$after" ]; then
    success "下载完成: $after (版本: ${after_ver:-unknown})"
  else
    warning "未自动定位到安装器，但下载命令已成功返回。请在 /Applications 中手动确认 'Install macOS *.app'"
  fi
}

validate_create_target_volume() {
  [ -n "$CREATE_VOLUME" ] || die "必须通过 --volume 指定目标卷，例如 --volume /Volumes/MyUSB"
  [ -d "$CREATE_VOLUME" ] || die "卷不存在: $CREATE_VOLUME"
  if [[ "$CREATE_VOLUME" != /Volumes/* ]]; then
    warning "目标卷不在 /Volumes 下，确保这是一个可抹写的可移动介质。"
  fi
}

resolve_create_installer_path() {
  if [ -z "$CREATE_INSTALLER_PATH" ]; then
    CREATE_INSTALLER_PATH="$(find_installer_app "$CREATE_VERSION" || true)"
    [ -n "$CREATE_INSTALLER_PATH" ] || die "未找到安装器。请先执行 'list' 和 'download'，或用 --installer-path 指定"
  fi
  [ -d "$CREATE_INSTALLER_PATH" ] || die "安装器路径无效: $CREATE_INSTALLER_PATH"
}

prepare_createinstallmedia_context() {
  CREATEINSTALLMEDIA_PATH="$CREATE_INSTALLER_PATH/Contents/Resources/createinstallmedia"
  [ -x "$CREATEINSTALLMEDIA_PATH" ] || die "缺少 createinstallmedia: $CREATEINSTALLMEDIA_PATH"

  CREATE_APP_VERSION="$(get_installer_short_ver "$CREATE_INSTALLER_PATH" || echo "unknown")"
  CREATE_APP_NAME="$(basename "$CREATE_INSTALLER_PATH")"
  CREATE_APP_LABEL="$(get_installer_label "$CREATE_INSTALLER_PATH")"

  log_info "目标卷: $CREATE_VOLUME"
  log_info "安装器: $CREATE_APP_NAME (版本 $CREATE_APP_VERSION)"
  log_debug "卷信息: $(diskutil info "$CREATE_VOLUME" | tr '\n' ' ' | sed 's/  */ /g')"
}

ensure_create_target_is_ready() {
  local vol_app="" vol_ver=""
  vol_app="$(detect_volume_installer_app "$CREATE_VOLUME" || true)"
  if [ -n "$vol_app" ]; then
    vol_ver="$(get_installer_short_ver "$vol_app")"
    log_info "卷上检测到安装器: $(basename "$vol_app") (版本: ${vol_ver:-unknown})"
    if [ -n "$vol_ver" ] && { [ "$vol_ver" = "$CREATE_APP_VERSION" ] || [[ "$vol_ver" == "$CREATE_APP_VERSION"* ]]; }; then
      success "目标卷已是同版本可启动安装器（$vol_ver），跳过制作。"
      return 1
    fi

    if [ "$CREATE_FORCE" != "yes" ]; then
      die "目标卷包含不同版本的安装器（$vol_ver）。使用 --force 覆盖，或更换目标卷。"
    fi

    warning "将按 --force 覆盖卷上现有内容（当前版本 $vol_ver -> 目标版本 $CREATE_APP_VERSION）。"
  else
    log_info "卷上未检测到安装器或为空，将继续创建。"
  fi

  return 0
}

confirm_create_target_wipe() {
  warning "此操作将抹掉 ${CREATE_VOLUME} 上的所有数据！"
  if [ "$CREATE_YES" != "yes" ]; then
    if [ "$CREATE_FORCE" = "yes" ]; then
      warning "已指定 --force，将覆盖可能存在的旧安装器或其他文件。"
    fi
    if ! confirm "是否继续" "N"; then
      die "已取消"
    fi
  else
    log_info "已通过 -y/--yes，跳过交互确认"
  fi
}
