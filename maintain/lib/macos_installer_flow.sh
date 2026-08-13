#!/bin/zsh
# filepath: maintain/lib/macos_installer_flow.sh

# 已获取的锁目录登记表，由入口脚本（macos_sys_usb_maker.sh）的
# 全局 trap 在脚本退出时统一清理。不要在函数内设置 EXIT trap：
# zsh 的函数级 trap 会在函数返回时立即触发，锁会被提前删除，
# 导致并发互斥保护失效。
INSTALLER_LOCK_DIRS=()

acquire_installer_lock() {
  local key="$(sanitize_key "$1")"
  LOCK_DIR="/tmp/${SCRIPT_NAME}.${key}.lock"
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    INSTALLER_LOCK_DIRS+=("$LOCK_DIR")
    log_debug "已获取锁: $LOCK_DIR"
  else
    die "另一个相同操作正在进行中（锁: $LOCK_DIR）。稍后重试。"
  fi
}

sub_list() {
  require_command softwareupdate

  print_header "列出可用的 macOS 完整安装器"
  log_info "系统: $(sw_vers -productName) $(sw_vers -productVersion)"
  log_info "softwareupdate 版本: $(softwareupdate --version 2>/dev/null || echo 'unknown')"

  print_step 1 1 "查询可用的完整安装器..."
  log_time_start "list_full_installers" "softwareupdate 查询完整安装器"
  if ! softwareupdate --list-full-installers; then
    log_time_end "list_full_installers" "softwareupdate 列表查询" "error"
    log_error "softwareupdate 列表查询失败"
    exit 1
  fi
  log_time_end "list_full_installers" "softwareupdate 列表查询"

  success "列表获取完成"
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

prepare_download_context() {
  require_command softwareupdate
  parse_download_args "$@"
  acquire_installer_lock "download_${DOWNLOAD_VERSION}"
}

check_existing_installer_before_download() {
  print_step 1 3 "检查已有安装器..."
  local existing=""
  existing="$(resolve_existing_installer_for_download)"
  if should_skip_installer_download "$existing"; then
    success "已存在版本 ${DOWNLOAD_VERSION} 的安装器：$existing，跳过下载（使用 --force 可强制重下）。"
    return 1
  fi
  [ -n "$existing" ] && warning "检测到已存在安装器: $existing，将按 --force 重新下载。"
  return 0
}

run_installer_download() {
  print_step 2 3 "开始下载 macOS 安装器版本: $(highlight "$DOWNLOAD_VERSION")"
  log_info "目标目录: /Applications (将生成 Install macOS *.app)"
  log_time_start "download_${DOWNLOAD_VERSION}" "softwareupdate 下载 ${DOWNLOAD_VERSION}"
  if ! softwareupdate --fetch-full-installer --full-installer-version "${DOWNLOAD_VERSION}"; then
    log_time_end "download_${DOWNLOAD_VERSION}" "macOS 安装器下载" "error"
    log_error "下载失败，请检查版本号是否有效、网络是否可用，或先执行 '$SCRIPT_NAME list' 查看可用版本。"
    exit 1
  fi
  log_time_end "download_${DOWNLOAD_VERSION}" "macOS 安装器下载"
}

complete_installer_download() {
  print_step 3 3 "校验下载结果..."
  verify_downloaded_installer
}

sub_download() {
  prepare_download_context "$@"

  print_header "下载 macOS 安装器"
  check_existing_installer_before_download || return 0
  run_installer_download
  complete_installer_download
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
      return 1
    fi

    warning "将按 --force 覆盖卷上现有内容（当前版本 $vol_ver -> 目标版本 $CREATE_APP_VERSION）。"
  else
    log_info "卷上未检测到安装器或为空，将继续创建。"
  fi

  return 0
}

run_createinstallmedia() {
  log_info "需要管理员权限，可能会提示输入密码。"
  log_time_start "createinstallmedia_${CREATE_VOLUME}" "写入安装器至 $CREATE_VOLUME"
  if ! sudo "$CREATEINSTALLMEDIA_PATH" --volume "$CREATE_VOLUME" --nointeraction; then
    log_time_end "createinstallmedia_${CREATE_VOLUME}" "createinstallmedia 执行" "error"
    log_error "createinstallmedia 执行失败。请检查 USB 是否可写、容量是否足够（建议 ≥ 16GB），或查看系统日志。"
    exit 1
  fi
  log_time_end "createinstallmedia_${CREATE_VOLUME}" "createinstallmedia 执行"
}

print_create_completion() {
  success "USB 启动盘制作完成: $CREATE_VOLUME（应被重命名为：$CREATE_APP_LABEL）"
  log_info "使用方法："
  log_info "- Apple Silicon: 关机后按住电源键进入启动选项，选择该 U 盘"
  log_info "- Intel Mac: 开机时按住 Option 键选择启动盘"
}

prepare_create_context() {
  parse_create_args "$@"
}

validate_create_prerequisites() {
  print_step 1 6 "校验参数与环境"

  validate_create_target_volume

  require_command sudo
  require_command diskutil
}

resolve_create_inputs() {
  print_step 2 6 "解析安装器路径与版本"
  resolve_create_installer_path
  prepare_createinstallmedia_context
}

check_create_target_readiness() {
  print_step 3 6 "幂等性检查"
  ensure_create_target_is_ready || return 1
  return 0
}

acquire_create_lock_and_confirm() {
  acquire_installer_lock "create_$(sanitize_key "$CREATE_VOLUME")"

  print_step 4 6 "确认将抹掉目标卷数据"
  confirm_create_target_wipe
}

run_create_execution() {
  print_step 5 6 "执行 createinstallmedia"
  run_createinstallmedia

  print_step 6 6 "收尾与提示"
  print_create_completion
}

sub_create() {
  prepare_create_context "$@"

  print_header "制作 macOS USB 启动盘"
  validate_create_prerequisites
  resolve_create_inputs
  check_create_target_readiness || return 0
  acquire_create_lock_and_confirm
  run_create_execution
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
