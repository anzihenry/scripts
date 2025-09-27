#!/bin/zsh
# macOS 安装器相关的辅助函数集合。
# 这些函数被 macos_sys_usb_maker.sh 等脚本复用，便于测试与维护。

if ! typeset -f log_debug >/dev/null 2>&1; then
  log_debug()  { [ "${DEBUG:-false}" = "true" ] && echo "[DEBUG] $*" >&2 || true; }
  log_warn()   { echo "[WARN] $*" >&2; }
  log_error()  { echo "[ERROR] $*" >&2; }
fi

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
  for candidate in "$vol"/Install\ macOS*.app; do
    [ -d "$candidate" ] && { echo "$candidate"; return 0; }
  done
  return 1
}

find_installer_app() {
  local want_version="${1:-}"
  local app found=""
  for app in /Applications/Install\ macOS*.app; do
    [ -d "$app" ] || continue
    if [ -n "$want_version" ]; then
      local ver=""
      ver="$(get_installer_short_ver "$app")"
      log_debug "检测到安装器: $app (版本: $ver)"
      if [ "$ver" = "$want_version" ] || [[ "$ver" == "$want_version"* ]]; then
        echo "$app"
        return 0
      fi
    else
      found="$app"
    fi
  done
  if [ -z "$want_version" ]; then
    found="$(/bin/ls -1t /Applications/Install\ macOS*.app 2>/dev/null | /usr/bin/head -n1 || true)"
    [ -n "$found" ] && { echo "$found"; return 0; }
  fi
  return 1
}

export MACOS_INSTALLER_UTILS_LOADED=true
