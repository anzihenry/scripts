#!/bin/zsh
# macOS 安装器相关的辅助函数集合。
# 这些函数被 macos_sys_usb_maker.sh 等脚本复用，便于测试与维护。

# shellcheck disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/../../lib/utils.sh"

sanitize_key() {
  echo "$1" | sed 's#[^A-Za-z0-9]#_#g'
}

get_installer_short_ver() {
  local app_path="$1"
  /usr/bin/defaults read "$app_path/Contents/Info" CFBundleShortVersionString 2>/dev/null || true
}

get_installer_label() {
  basename "$1" .app
}

detect_volume_installer_app() {
  local vol="$1"
  local candidate
   # zsh: 使用 (N) 避免无匹配时抛出 nomatch
   setopt local_options nonomatch
   for candidate in "$vol"/Install\ macOS*.app(N); do
    [ -d "$candidate" ] && { echo "$candidate"; return 0; }
  done
  return 1
}

installer_version_matches() {
  local actual="$1" requested="$2"
  [[ -n "$actual" && -n "$requested" ]] && { [[ "$actual" == "$requested" ]] || [[ "$actual" == "$requested".* ]]; }
}

installer_is_complete() {
  local app="$1" payload="$1/Contents/SharedSupport/SharedSupport.dmg"
  [[ -x "$app/Contents/Resources/createinstallmedia" && -s "$app/Contents/Info.plist" ]] || return 1
  [[ -s "$payload" ]] || payload="$app/Contents/SharedSupport/InstallESD.dmg"
  [[ -s "$payload" ]] || return 1
  hdiutil verify "$payload" >/dev/null 2>&1
}

# 系统版本取自安装载荷元数据，不能把 InstallAssistant 应用版本当成 macOS 版本。
# 载荷布局参考上游实现：https://github.com/grahampugh/erase-install
get_installer_os_version() (
  local app="$1" metadata="$1/Contents/SharedSupport/InstallInfo.plist" version mount attached=false
  if [[ -f "$metadata" ]]; then
    version="$(plutil -extract 'System Image Info.version' raw -o - "$metadata" 2>/dev/null)" || version=""
    if [[ "$version" =~ ^[0-9]+([.][0-9]+){1,2}$ ]]; then printf '%s' "$version"; return 0; fi
  fi
  [[ -s "$app/Contents/SharedSupport/SharedSupport.dmg" ]] || return 1
  mount="$(mktemp -d "${TMPDIR:-/tmp}/macos-installer-metadata.XXXXXXXX")" || return 1
  trap 'if [[ "$attached" == true ]]; then hdiutil detach "$mount" >/dev/null 2>&1 || { error "无法卸载只读安装映像，请手动检查: $mount"; return 1; }; fi; rmdir "$mount"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM HUP
  hdiutil attach -readonly -nobrowse -noautoopen -mountpoint "$mount" "$app/Contents/SharedSupport/SharedSupport.dmg" >/dev/null || return 1
  attached=true
  local relative
  for relative in com_apple_MobileAsset_MacSoftwareUpdate/com_apple_MobileAsset_MacSoftwareUpdate.xml SFR/com_apple_MobileAsset_SFRSoftwareUpdate/com_apple_MobileAsset_SFRSoftwareUpdate.xml; do
    [[ -f "$mount/$relative" ]] || continue
    version="$(plutil -extract Assets.0.OSVersion raw -o - "$mount/$relative" 2>/dev/null)" || continue
    if [[ "$version" =~ ^[0-9]+([.][0-9]+){1,2}$ ]]; then printf '%s' "$version"; return 0; fi
  done
  return 1
)

installer_volume_value() {
  diskutil info -plist "$1" | plutil -extract "$2" raw -o - -
}

installer_source_identity() {
  local payload="$1/Contents/SharedSupport/SharedSupport.dmg"
  [[ -s "$payload" ]] || payload="$1/Contents/SharedSupport/InstallESD.dmg"
  [[ -s "$payload" && -s "$1/Contents/Info.plist" ]] || return 1
  shasum -a 256 "$1/Contents/Info.plist" "$payload" | awk '{print $1}'
}

volume_creation_current() {
  local uuid marker app
  uuid="$(installer_volume_value "$CREATE_VOLUME" VolumeUUID)" || return 1
  [[ -n "$uuid" && "$uuid" != *[^A-Za-z0-9-]* ]] || return 1
  marker="${MACOS_SCRIPTS_CONFIG_DIR:-$HOME/.config/macos-scripts}/installer-state/$uuid"
  [[ -f "$marker" && "$(<"$marker")" == "$CREATE_SOURCE_ID" ]] || return 1
  app="$(detect_volume_installer_app "$CREATE_VOLUME")" || return 1
  [[ "$(get_installer_short_ver "$app")" == "$CREATE_APP_VERSION" ]] || return 1
  [[ "$(installer_source_identity "$app")" == "$CREATE_SOURCE_ID" ]] || return 1
  [[ -f "$CREATE_VOLUME/.IAPhysicalMedia" || -s "$CREATE_VOLUME/.IABootFiles/boot.efi" || -s "$CREATE_VOLUME/System/Library/CoreServices/boot.efi" ]]
}

record_volume_creation() {
  # createinstallmedia 可能重命名卷；用原设备重新定位挂载点和新 UUID。
  local mount uuid directory candidate
  mount="$(installer_volume_value "$CREATE_DEVICE" MountPoint)" || return 1
  uuid="$(installer_volume_value "$CREATE_DEVICE" VolumeUUID)" || return 1
  [[ -n "$uuid" && "$uuid" != *[^A-Za-z0-9-]* && -d "$mount" ]] || return 1
  CREATE_VOLUME="$mount"
  directory="${MACOS_SCRIPTS_CONFIG_DIR:-$HOME/.config/macos-scripts}/installer-state"
  mkdir -p "$directory" || return 1
  candidate="$(mktemp "$directory/.complete.XXXXXXXX")" || return 1
  printf '%s\n' "$CREATE_SOURCE_ID" > "$candidate" && mv -f "$candidate" "$directory/$uuid" || { rm -f "$candidate"; return 1; }
}

find_installer_app() {
  local want_version="${1:-}"
  local app
   # zsh: 使用 (N) 避免无匹配时抛出 nomatch
   setopt local_options nonomatch
   for app in /Applications/Install\ macOS*.app(Nom); do
    [ -d "$app" ] || continue
    installer_is_complete "$app" || continue
    if [ -n "$want_version" ]; then
      local ver=""
      ver="$(get_installer_os_version "$app")" || continue
      log_debug "检测到安装器: $app (版本: $ver)"
      if installer_version_matches "$ver" "$want_version"; then
        echo "$app"
        return 0
      fi
    else
      printf '%s\n' "$app"
      return 0
    fi
  done
  return 1
}

export MACOS_INSTALLER_UTILS_LOADED=true
