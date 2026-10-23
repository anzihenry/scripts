#!/bin/zsh
# filepath: maintain/lib/macos_installer_flow.sh

# 跳过和失败使用不同状态，调用方只将已就绪状态转换为成功。
INSTALLER_ALREADY_CURRENT=10

# 判断锁目录的持有进程是否仍存活。只认明确的「进程不存在」；
# 任何不确定情况（无 ps、读取失败、仅剩僵尸/孤儿目录）都保守视为存活，
# 避免误删他人正在持有的锁而破坏互斥。
_installer_lock_owner_alive() {
  local lock_dir="$1"
  local info_file="$lock_dir/pid"
  local pid=""

  [[ -r "$info_file" ]] || return 0
  pid="$(<"$info_file")"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 0
  [[ "$pid" -gt 0 ]] || return 0
  # 自己持有
  [[ "$pid" -eq "$$" ]] && return 0

  if command -v ps > /dev/null 2>&1; then
    if ps -p "$pid" > /dev/null 2>&1; then
      return 0
    fi
    return 1
  fi

  if kill -0 "$pid" 2> /dev/null; then
    return 0
  fi
  case "$(kill -0 "$pid" 2>&1)" in
    *"No such process"*) return 1 ;;
    *) return 0 ;;
  esac
}

acquire_installer_lock() {
  local key legacy
  key="$(sanitize_key "$1")" || return 1
  legacy="/tmp/${SCRIPT_NAME}.${key}.lock"
  if [[ -e "$legacy" ]] && _installer_lock_owner_alive "$legacy"; then
    error "旧版安装器锁仍存在且无法确认已结束，请检查后重试: $legacy"
    return 1
  fi
  # 资源名不依赖入口脚本名称；锁由内核释放，不删除陈旧目录或锁文件。
  resource_lock_acquire "macos-installer:$key"
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
    return 1
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
    error "未找到版本匹配且通过完整性检查的安装器，请检查 /Applications 后重试。"
    return 1
  fi
}

prepare_download_context() {
  parse_download_args "$@" || return $?
  initialize_macos_installer_logging || return $?
  require_supported_macos || return 1
  require_commands softwareupdate hdiutil || return 1
  acquire_installer_lock download_full_installer || return $?
}

check_existing_installer_before_download() {
  print_step 1 3 "检查已有安装器..."
  local existing=""
  existing="$(resolve_existing_installer_for_download)"
  if should_skip_installer_download "$existing"; then
    success "已存在版本 ${DOWNLOAD_VERSION} 的安装器：$existing，跳过下载（使用 --force 可强制重下）。"
    return "$INSTALLER_ALREADY_CURRENT"
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
    return 1
  fi
  log_time_end "download_${DOWNLOAD_VERSION}" "macOS 安装器下载"
}

complete_installer_download() {
  print_step 3 3 "校验下载结果..."
  verify_downloaded_installer
}

sub_download() {
  prepare_download_context "$@" || return $?

  print_header "下载 macOS 安装器"
  local check_code=0
  check_existing_installer_before_download || check_code=$?
  (( check_code != INSTALLER_ALREADY_CURRENT )) || return 0
  (( check_code == 0 )) || return "$check_code"
  run_installer_download || return $?
  complete_installer_download || return $?
}

validate_create_target_volume() {
  [ -n "$CREATE_VOLUME" ] || { error "必须通过 --volume 指定目标卷，例如 --volume /Volumes/MyUSB"; return 1; }
  [ -d "$CREATE_VOLUME" ] || { error "卷不存在: $CREATE_VOLUME"; return 1; }
  if [[ "$CREATE_VOLUME" != /Volumes/* ]]; then
    warning "目标卷不在 /Volumes 下，确保这是一个可抹写的可移动介质。"
  fi
}

resolve_create_installer_path() {
  if [ -z "$CREATE_INSTALLER_PATH" ]; then
    CREATE_INSTALLER_PATH="$(find_installer_app "$CREATE_VERSION" || true)"
    [ -n "$CREATE_INSTALLER_PATH" ] || { error "未找到安装器。请先执行 'list' 和 'download'，或用 --installer-path 指定"; return 1; }
  fi
  [ -d "$CREATE_INSTALLER_PATH" ] || { error "安装器路径无效: $CREATE_INSTALLER_PATH"; return 1; }
  installer_is_complete "$CREATE_INSTALLER_PATH" || { error "安装器不完整或磁盘映像校验失败，请重新下载: $CREATE_INSTALLER_PATH"; return 1; }
}

prepare_createinstallmedia_context() {
  CREATEINSTALLMEDIA_PATH="$CREATE_INSTALLER_PATH/Contents/Resources/createinstallmedia"
  [ -x "$CREATEINSTALLMEDIA_PATH" ] || { error "缺少 createinstallmedia: $CREATEINSTALLMEDIA_PATH"; return 1; }

  CREATE_APP_VERSION="$(get_installer_short_ver "$CREATE_INSTALLER_PATH")"
  [[ -n "$CREATE_APP_VERSION" ]] || { error "无法读取安装器版本"; return 1; }
  CREATE_DEVICE="$(installer_volume_value "$CREATE_VOLUME" DeviceIdentifier)" || { error "无法确认目标卷设备"; return 1; }
  if [[ -n "$CREATE_VERSION" ]]; then
    local source_os
    source_os="$(get_installer_os_version "$CREATE_INSTALLER_PATH")" || { error "无法读取安装载荷的 macOS 版本"; return 1; }
    installer_version_matches "$source_os" "$CREATE_VERSION" || { error "指定安装器与请求的 macOS 版本不匹配"; return 1; }
  fi
  CREATE_SOURCE_ID="$(installer_source_identity "$CREATE_INSTALLER_PATH")" || { error "无法校验安装器身份"; return 1; }
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
    if [[ "$CREATE_FORCE" != yes && "$vol_ver" == "$CREATE_APP_VERSION" ]] && volume_creation_current; then
      success "目标卷已是同版本可启动安装器（$vol_ver），跳过制作。"
      return "$INSTALLER_ALREADY_CURRENT"
    fi

    if [ "$CREATE_FORCE" != "yes" ]; then
      error "目标卷包含不同版本或没有可信完成记录的安装器（$vol_ver）。使用 --force 覆盖，或更换目标卷。"
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
    return 1
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
  parse_create_args "$@" || return $?
  initialize_macos_installer_logging || return $?
  require_supported_macos || return 1
}

validate_create_prerequisites() {
  print_step 1 6 "校验参数与环境"

  validate_create_target_volume || return $?

  require_command sudo
  require_commands diskutil hdiutil plutil shasum || return 1
}

resolve_create_inputs() {
  print_step 2 6 "解析安装器路径与版本"
  resolve_create_installer_path || return $?
  prepare_createinstallmedia_context || return $?
}

check_create_target_readiness() {
  print_step 3 6 "幂等性检查"
  ensure_create_target_is_ready || return $?
  return 0
}

acquire_create_lock_and_confirm() {

  print_step 4 6 "确认将抹掉目标卷数据"
  confirm_create_target_wipe
}

run_create_execution() {
  print_step 5 6 "执行 createinstallmedia"
  run_createinstallmedia || return $?
  record_volume_creation || { error "制作命令成功，但无法记录完成状态，请检查目标卷后重试。"; return 1; }

  print_step 6 6 "收尾与提示"
  print_create_completion
}

sub_create() {
  prepare_create_context "$@" || return $?

  print_header "制作 macOS USB 启动盘"
  validate_create_prerequisites || return $?
  resolve_create_inputs || return $?
  acquire_installer_lock "create_$(sanitize_key "$CREATE_DEVICE")" || return $?
  [[ "$(installer_volume_value "$CREATE_VOLUME" DeviceIdentifier)" == "$CREATE_DEVICE" ]] || { error "目标卷设备已变化，已中止，请重新运行。"; return 1; }
  local check_code=0
  check_create_target_readiness || check_code=$?
  (( check_code != INSTALLER_ALREADY_CURRENT )) || return 0
  (( check_code == 0 )) || return "$check_code"
  acquire_create_lock_and_confirm || return $?
  run_create_execution || return $?
}

confirm_create_target_wipe() {
  warning "此操作将抹掉 ${CREATE_VOLUME} 上的所有数据！"
  if [ "$CREATE_YES" != "yes" ]; then
    if [ "$CREATE_FORCE" = "yes" ]; then
      warning "已指定 --force，将覆盖可能存在的旧安装器或其他文件。"
    fi
    if ! confirm "是否继续" "N"; then
      warning "已取消"
      return 1
    fi
  else
    log_info "已通过 -y/--yes，跳过交互确认"
  fi
}
