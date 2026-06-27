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
# shellcheck disable=SC1090
source "$SCRIPT_DIR/lib/macos_installer_utils.sh"

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
