#!/bin/zsh
# macOS 系统安装器下载与 USB 启动盘制作工具
# 子命令：
#   1) download --version <x.y[.z]>     使用 softwareupdate 下载指定版本完整安装器
#   2) create --volume /Volumes/XXX [--installer-path "..."] [--version <x.y[.z]>] [-y]
#   3) list                             列出可用的完整安装器版本
# 示例：
#   macos_sys_usb_maker.sh list
#   macos_sys_usb_maker.sh download --version 14.6.1
#   macos_sys_usb_maker.sh create --volume /Volumes/MyUSB --version 14.6 -y

set -e
set -u
set -o pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ==== 日志与颜色：集成 colors.sh ====
case $- in *u*) __HAD_U=1;; *) __HAD_U=0;; esac
set +u
if [ -f "$SCRIPT_DIR/../lib/colors.sh" ]; then
  # shellcheck disable=SC1090
  source "$SCRIPT_DIR/../lib/colors.sh"
else
  log_info()   { echo "[INFO] $*" >&2; }
  log_warn()   { echo "[WARN] $*" >&2; }
  log_error()  { echo "[ERROR] $*" >&2; }
  log_debug()  { [ "${DEBUG:-false}" = "true" ] && echo "[DEBUG] $*" >&2 || true; }
  log_success(){ echo "[SUCCESS] $*" >&2; }
  log_fatal()  { echo "[FATAL] $*" >&2; exit 1; }
  print_header(){ echo "==== $1 ===="; }
  print_step() { echo "[$1/$2] $3"; }
  highlight()  { echo "$*"; }
  warning()    { log_warn "$@"; }
  success()    { log_success "$@"; }
fi
[ $__HAD_U -eq 1 ] && set -u

die() { log_fatal "$@"; }

VERBOSE="false"

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
示例:
  $SCRIPT_NAME list
  $SCRIPT_NAME download --version 14.6.1
  $SCRIPT_NAME create --volume /Volumes/MyUSB --version 14.6 -y
EOF
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"
}

# ---------- 工具与幂等辅助 ----------
sanitize_key() { echo "$1" | sed 's#[^A-Za-z0-9]#_#g'; }

LOCK_DIR=""
acquire_lock() {
  local key="$(sanitize_key "$1")"
  LOCK_DIR="/tmp/${SCRIPT_NAME}.${key}.lock"
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    trap 'rm -rf "$LOCK_DIR"' EXIT INT TERM HUP
    log_debug "已获取锁: $LOCK_DIR"
  else
    die "另一个相同操作正在进行中（锁: $LOCK_DIR）。稍后重试。"
  fi
}

get_installer_short_ver() {
  # $1: path to Install macOS*.app
  /usr/bin/defaults read "$1/Contents/Info" CFBundleShortVersionString 2>/dev/null || true
}

get_installer_label() {
  # Install macOS Sequoia.app -> Install macOS Sequoia
  basename "$1" .app
}

detect_volume_installer_app() {
  # 返回卷根目录下的第一个安装器 app 路径
  local vol="$1"
  local a
  for a in "$vol"/Install\ macOS*.app; do
    [ -d "$a" ] && { echo "$a"; return 0; }
  done
  return 1
}

# 自动发现 /Applications 中的安装器
find_installer_app() {
  local WANT_VERSION="${1:-}"
  local app
  local found=""
  for app in /Applications/Install\ macOS*.app; do
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

# ------------------- 子命令：list -------------------
sub_list() {
  need_cmd softwareupdate

  print_header "列出可用的 macOS 完整安装器"
  log_info "系统: $(sw_vers -productName) $(sw_vers -productVersion)"
  log_info "softwareupdate 版本: $(softwareupdate --version 2>/dev/null || echo 'unknown')"

  print_step 1 1 "查询可用的完整安装器..."
  if ! softwareupdate --list-full-installers; then
    log_error "softwareupdate 列表查询失败"
    exit 1
  fi

  success "列表获取完成"
}

# ------------------- 子命令：download -------------------
# 幂等策略：存在目标版本即跳过；--force 强制重下
sub_download() {
  need_cmd softwareupdate

  local VERSION=""
  local FORCE="no"
  while [ $# -gt 0 ]; do
    case "$1" in
      --version) VERSION="${2:-}"; shift 2;;
      --force|-f) FORCE="yes"; shift;;
      -v|--verbose) VERBOSE="true"; shift;;
      -h|--help) usage; exit 0;;
      *) die "未知参数: $1";;
    esac
  done
  [ -n "${VERSION}" ] || die "请通过 --version 指定版本号，例如 --version 14.6.1"
  [ "$VERBOSE" = "true" ] && export DEBUG=true

  acquire_lock "download_${VERSION}"

  print_header "下载 macOS 安装器"
  print_step 1 3 "检查已有安装器..."
  local existing=""
  existing="$(find_installer_app "$VERSION" || true)"
  if [ -n "$existing" ] && [ "$FORCE" != "yes" ]; then
    success "已存在版本 ${VERSION} 的安装器：$existing，跳过下载（使用 --force 可强制重下）。"
    return 0
  fi
  [ -n "$existing" ] && warning "检测到已存在安装器: $existing，将按 --force 重新下载。"

  print_step 2 3 "开始下载 macOS 安装器版本: $(highlight "$VERSION")"
  log_info "目标目录: /Applications (将生成 Install macOS *.app)"
  if ! softwareupdate --fetch-full-installer --full-installer-version "${VERSION}"; then
    log_error "下载失败，请检查版本号是否有效、网络是否可用，或先执行 '$SCRIPT_NAME list' 查看可用版本。"
    exit 1
  fi

  print_step 3 3 "校验下载结果..."
  local after="" after_ver=""
  after="$(find_installer_app "$VERSION" || true)"
  [ -n "$after" ] && after_ver="$(get_installer_short_ver "$after")"
  if [ -n "$after" ]; then
    success "下载完成: $after (版本: ${after_ver:-unknown})"
  else
    warning "未自动定位到安装器，但下载命令已成功返回。请在 /Applications 中手动确认 'Install macOS *.app'"
  fi
}

# ------------------- 子命令：create -------------------
# 幂等策略：
# - 若卷根已有 Install macOS*.app 且版本等于待写入安装器版本 => 直接成功并跳过
# - 若卷已有其它版本安装器或非空内容 => 需要 --force 才覆盖（并抹盘）
sub_create() {
  local VOLUME=""
  local INSTALLER_PATH=""
  local VERSION=""
  local YES="no"
  local FORCE="no"

  while [ $# -gt 0 ]; do
    case "$1" in
      --volume) VOLUME="${2:-}"; shift 2;;
      --installer-path) INSTALLER_PATH="${2:-}"; shift 2;;
      --version) VERSION="${2:-}"; shift 2;;
      -y|--yes|--nointeraction) YES="yes"; shift;;
      --force|-f) FORCE="yes"; shift;;
      -v|--verbose) VERBOSE="true"; shift;;
      -h|--help) usage; exit 0;;
      *) die "未知参数: $1";;
    esac
  done

  [ "$VERBOSE" = "true" ] && export DEBUG=true

  print_header "制作 macOS USB 启动盘"
  print_step 1 6 "校验参数与环境"

  [ -n "$VOLUME" ] || die "必须通过 --volume 指定目标卷，例如 --volume /Volumes/MyUSB"
  [ -d "$VOLUME" ] || die "卷不存在: $VOLUME"
  if [[ "$VOLUME" != /Volumes/* ]]; then
    warning "目标卷不在 /Volumes 下，确保这是一个可抹写的可移动介质。"
  fi

  need_cmd sudo
  need_cmd diskutil

  print_step 2 6 "解析安装器路径与版本"
  if [ -z "$INSTALLER_PATH" ]; then
    INSTALLER_PATH="$(find_installer_app "$VERSION" || true)"
    [ -n "$INSTALLER_PATH" ] || die "未找到安装器。请先执行 'list' 和 'download'，或用 --installer-path 指定"
  fi
  [ -d "$INSTALLER_PATH" ] || die "安装器路径无效: $INSTALLER_PATH"

  local CIM="$INSTALLER_PATH/Contents/Resources/createinstallmedia"
  [ -x "$CIM" ] || die "缺少 createinstallmedia: $CIM"

  local APP_VER APP_NAME APP_LABEL
  APP_VER="$(get_installer_short_ver "$INSTALLER_PATH" || echo "unknown")"
  APP_NAME="$(basename "$INSTALLER_PATH")"
  APP_LABEL="$(get_installer_label "$INSTALLER_PATH")"

  log_info "目标卷: $VOLUME"
  log_info "安装器: $APP_NAME (版本 $APP_VER)"
  log_debug "卷信息: $(diskutil info "$VOLUME" | tr '\n' ' ' | sed 's/  */ /g')"

  print_step 3 6 "幂等性检查"
  local VOL_APP="" VOL_VER=""
  VOL_APP="$(detect_volume_installer_app "$VOLUME" || true)"
  if [ -n "$VOL_APP" ]; then
    VOL_VER="$(get_installer_short_ver "$VOL_APP")"
    log_info "卷上检测到安装器: $(basename "$VOL_APP") (版本: ${VOL_VER:-unknown})"
    if [ -n "$VOL_VER" ] && { [ "$VOL_VER" = "$APP_VER" ] || [[ "$VOL_VER" == "$APP_VER"* ]]; }; then
      success "目标卷已是同版本可启动安装器（$VOL_VER），跳过制作。"
      return 0
    else
      if [ "$FORCE" != "yes" ]; then
        die "目标卷包含不同版本的安装器（$VOL_VER）。使用 --force 覆盖，或更换目标卷。"
      else
        warning "将按 --force 覆盖卷上现有内容（当前版本 $VOL_VER -> 目标版本 $APP_VER）。"
      fi
    fi
  else
    log_info "卷上未检测到安装器或为空，将继续创建。"
  fi

  acquire_lock "create_$(sanitize_key "$VOLUME")"

  print_step 4 6 "确认将抹掉目标卷数据"
  warning "此操作将抹掉 ${VOLUME} 上的所有数据！"
  if [ "$YES" != "yes" ]; then
    if [ "$FORCE" = "yes" ]; then
      warning "已指定 --force，将覆盖可能存在的旧安装器或其他文件。"
    fi
    if ! confirm "是否继续" "N"; then
      die "已取消"
    fi
  else
    log_info "已通过 -y/--yes，跳过交互确认"
  fi

  print_step 5 6 "执行 createinstallmedia"
  log_info "需要管理员权限，可能会提示输入密码。"
  if ! sudo "$CIM" --volume "$VOLUME" --nointeraction; then
    log_error "createinstallmedia 执行失败。请检查 USB 是否可写、容量是否足够（建议 ≥ 16GB），或查看系统日志。"
    exit 1
  fi

  print_step 6 6 "收尾与提示"
  success "USB 启动盘制作完成: $VOLUME（应被重命名为：$APP_LABEL）"
  log_info "使用方法："
  log_info "- Apple Silicon: 关机后按住电源键进入启动选项，选择该 U 盘"
  log_info "- Intel Mac: 开机时按住 Option 键选择启动盘"
}

# ------------------- 主入口 -------------------
main() {
  [ $# -ge 1 ] || { usage; exit 1; }

  case "${1:-}" in
    -v|--verbose) VERBOSE="true"; shift;;
  esac
  [ "$VERBOSE" = "true" ] && export DEBUG=true

  case "${1:-}" in
    list) shift; sub_list "$@";;
    download) shift; sub_download "$@";;
    create) shift; sub_create "$@";;
    -h|--help|help) usage;;
    *) log_error "未知子命令: ${1:-}"; usage; exit 1;;
  esac
}

main "$@"