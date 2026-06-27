#!/bin/zsh
# macOS 系统安装器下载与 USB 启动盘制作工具
# 子命令：
#   1) download --version <x.y[.z]>     使用 softwareupdate 下载指定版本完整安装器
#   2) create --volume /Volumes/XXX [--installer-path "..."] [--version <x.y[.z]>] [-y]
#   3) list                             列出可用的完整安装器版本
# 示例：
#   macos_sys_usb_maker.sh list
#   macos_sys_usb_maker.sh download --version 26.2
#   macos_sys_usb_maker.sh create --volume /Volumes/Install\ macOS\ Tahoe/ --installer-path /Applications/Install\ macOS\ Tahoe.app --force

set -e
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ==== 日志与颜色：集成 utils.sh（自动加载 colors.sh 并提供 fallback）====
# shellcheck disable=SC1090
source "$SCRIPT_DIR/../lib/utils.sh"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/lib/macos_installer_args.sh"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/lib/macos_installer_commands.sh"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/lib/macos_installer_flow.sh"

if [ -f "$SCRIPT_DIR/lib/macos_installer_utils.sh" ]; then
  # shellcheck disable=SC1090
  source "$SCRIPT_DIR/lib/macos_installer_utils.sh"
else
  log_warn "未找到 macos_installer_utils.sh，将使用脚本内置的简化逻辑。"
  sanitize_key() { echo "$1" | sed 's#[^A-Za-z0-9]#_#g'; }
  get_installer_short_ver() { /usr/bin/defaults read "$1/Contents/Info" CFBundleShortVersionString 2>/dev/null || true; }
  get_installer_label() { basename "$1" .app; }
  detect_volume_installer_app() {
    # zsh: 使用 (N) 避免无匹配时抛出 nomatch
    setopt local_options nonomatch
    local vol="$1" a
    for a in "$vol"/Install\ macOS*.app(N); do
      [ -d "$a" ] && { echo "$a"; return 0; }
    done
    return 1
  }
  find_installer_app() {
    # zsh: 使用 (N) 避免无匹配时抛出 nomatch
    setopt local_options nonomatch
    local WANT_VERSION="${1:-}" app found=""
    for app in /Applications/Install\ macOS*.app(N); do
      [ -d "$app" ] || continue
      if [ -n "$WANT_VERSION" ]; then
        local ver=""
        ver="$(get_installer_short_ver "$app")"
        log_debug "检测到安装器: $app (版本: $ver)"
        if [ "$ver" = "$WANT_VERSION" ] || [[ "$ver" == "$WANT_VERSION"* ]]; then
          echo "$app"
          return 0
        fi
      else
        found="$app"
      fi
    done
    if [ -z "$WANT_VERSION" ]; then
      found="$(/bin/ls -1t /Applications/Install\ macOS*.app 2>/dev/null | /usr/bin/head -n1 || true)"
      [ -n "$found" ] && { echo "$found"; return 0; }
    fi
    return 1
  }
fi

die() { log_fatal "$@"; }

usage() {
  cat <<EOF
用法:
  $SCRIPT_NAME [--verbose] list
  $SCRIPT_NAME [--verbose] download --version <x.y[.z]> [--force]
  $SCRIPT_NAME [--verbose] create --volume /Volumes/YourUSB [--installer-path "/Applications/Install macOS *.app"] [--version <x.y[.z]>] [-y] [--force]

说明:
  list        列出可用完整安装器版本 (softwareupdate --list-full-installers)
  download    幂等：若指定版本安装器已在 /Applications 中则跳过；--force 可强制重新下载
  create      幂等：若目标卷已是同版本可启动安装器则跳过；不同版本需 --force 才覆盖（会抹掉分区）
  日志        默认写入 ${MAINTAIN_LOG_FILE}
示例:
  $SCRIPT_NAME list
  $SCRIPT_NAME download --version 14.6.1
  $SCRIPT_NAME create --volume /Volumes/MyUSB --version 14.6 -y
EOF
}

# ------------------- 子命令：list -------------------
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

# ------------------- 子命令：download -------------------
# 幂等策略：存在目标版本即跳过；--force 强制重下
sub_download() {
  require_command softwareupdate

  parse_download_args "$@"

  acquire_installer_lock "download_${DOWNLOAD_VERSION}"

  print_header "下载 macOS 安装器"
  print_step 1 3 "检查已有安装器..."
  local existing=""
  existing="$(resolve_existing_installer_for_download)"
  if should_skip_installer_download "$existing"; then
    success "已存在版本 ${DOWNLOAD_VERSION} 的安装器：$existing，跳过下载（使用 --force 可强制重下）。"
    return 0
  fi
  [ -n "$existing" ] && warning "检测到已存在安装器: $existing，将按 --force 重新下载。"

  print_step 2 3 "开始下载 macOS 安装器版本: $(highlight "$DOWNLOAD_VERSION")"
  log_info "目标目录: /Applications (将生成 Install macOS *.app)"
  log_time_start "download_${DOWNLOAD_VERSION}" "softwareupdate 下载 ${DOWNLOAD_VERSION}"
  if ! softwareupdate --fetch-full-installer --full-installer-version "${DOWNLOAD_VERSION}"; then
    log_time_end "download_${DOWNLOAD_VERSION}" "macOS 安装器下载" "error"
    log_error "下载失败，请检查版本号是否有效、网络是否可用，或先执行 '$SCRIPT_NAME list' 查看可用版本。"
    exit 1
  fi
  log_time_end "download_${DOWNLOAD_VERSION}" "macOS 安装器下载"

  print_step 3 3 "校验下载结果..."
  verify_downloaded_installer
}

# ------------------- 子命令：create -------------------
# 幂等策略：
# - 若卷根已有 Install macOS*.app 且版本等于待写入安装器版本 => 直接成功并跳过
# - 若卷已有其它版本安装器或非空内容 => 需要 --force 才覆盖（并抹盘）
sub_create() {
  parse_create_args "$@"

  print_header "制作 macOS USB 启动盘"
  print_step 1 6 "校验参数与环境"

  validate_create_target_volume

  require_command sudo
  require_command diskutil

  print_step 2 6 "解析安装器路径与版本"
  resolve_create_installer_path
  prepare_createinstallmedia_context

  print_step 3 6 "幂等性检查"
  ensure_create_target_is_ready || return 0

  acquire_installer_lock "create_$(sanitize_key "$CREATE_VOLUME")"

  print_step 4 6 "确认将抹掉目标卷数据"
  confirm_create_target_wipe

  print_step 5 6 "执行 createinstallmedia"
  log_info "需要管理员权限，可能会提示输入密码。"
  log_time_start "createinstallmedia_${CREATE_VOLUME}" "写入安装器至 $CREATE_VOLUME"
  if ! sudo "$CREATEINSTALLMEDIA_PATH" --volume "$CREATE_VOLUME" --nointeraction; then
    log_time_end "createinstallmedia_${CREATE_VOLUME}" "createinstallmedia 执行" "error"
    log_error "createinstallmedia 执行失败。请检查 USB 是否可写、容量是否足够（建议 ≥ 16GB），或查看系统日志。"
    exit 1
  fi
  log_time_end "createinstallmedia_${CREATE_VOLUME}" "createinstallmedia 执行"

  print_step 6 6 "收尾与提示"
  success "USB 启动盘制作完成: $CREATE_VOLUME（应被重命名为：$CREATE_APP_LABEL）"
  log_info "使用方法："
  log_info "- Apple Silicon: 关机后按住电源键进入启动选项，选择该 U 盘"
  log_info "- Intel Mac: 开机时按住 Option 键选择启动盘"
}

# ------------------- 主入口 -------------------
main() {
  initialize_macos_installer_context
  parse_macos_installer_global_args "$@"
  set -- "${REMAINING_ARGS[@]}"

  [ $# -ge 1 ] || { usage; exit 1; }

  log_info "日志文件位置: $MAINTAIN_LOG_FILE"
  dispatch_macos_installer_command "$@"
}

main "$@"
