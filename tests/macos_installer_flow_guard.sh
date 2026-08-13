#!/bin/zsh
# filepath: tests/macos_installer_flow_guard.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS_COUNT=0

pass() {
  printf '[PASS] %s\n' "$1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local name="$3"

  if [[ "$actual" != "$expected" ]]; then
    printf 'expected: %s\nactual:   %s\n' "$expected" "$actual" >&2
    fail "$name"
  fi

  pass "$name"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local name="$3"

  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'missing substring: %s\noutput: %s\n' "$needle" "$haystack" >&2
    fail "$name"
  fi

  pass "$name"
}

log_info() { printf 'INFO:%s\n' "$*"; }
log_debug() { printf 'DEBUG:%s\n' "$*"; }
warning() { printf 'WARN:%s\n' "$*"; }
success() { printf 'SUCCESS:%s\n' "$*"; }
log_error() { printf 'ERROR:%s\n' "$*" >&2; }
die() {
  printf 'DIE:%s\n' "$*" >&2
  return 1
}
confirm() { return 0; }
highlight() { printf '%s' "$*"; }
print_header() { printf 'HEADER:%s\n' "$1"; }
print_step() { printf 'STEP:%s/%s:%s\n' "$1" "$2" "$3"; }
log_time_start() { printf 'TIME_START:%s|%s\n' "$1" "$2"; }
log_time_end() { printf 'TIME_END:%s|%s|%s\n' "$1" "$2" "${3:-ok}"; }
require_command() { return 0; }
sanitize_key() { printf '%s' "$1"; }

# shellcheck disable=SC1091
source "$REPO_ROOT/maintain/lib/macos_installer_flow.sh"

test_should_skip_installer_download() {
  DOWNLOAD_FORCE="no"
  [[ "$(should_skip_installer_download "/Applications/Install macOS.app"; printf '%s' "$?")" == "0" ]] || fail "should skip when installer exists without force"
  pass "should skip when installer exists without force"

  DOWNLOAD_FORCE="yes"
  [[ "$(should_skip_installer_download "/Applications/Install macOS.app"; printf '%s' "$?")" == "1" ]] || fail "does not skip when force is enabled"
  pass "does not skip when force is enabled"

  DOWNLOAD_FORCE="no"
  [[ "$(should_skip_installer_download ""; printf '%s' "$?")" == "1" ]] || fail "does not skip when installer is absent"
  pass "does not skip when installer is absent"
}

test_resolve_create_installer_path_uses_discovery() {
  local temp_root=""
  local discovered_app=""
  temp_root="$(mktemp -d "${TMPDIR:-/tmp}/macos-installer-guard.XXXXXX")"
  discovered_app="$temp_root/Install macOS Sonoma.app"
  mkdir -p "$discovered_app"

  CREATE_INSTALLER_PATH=""
  CREATE_VERSION="14.6"
  find_installer_app() {
    printf '%s' "$discovered_app"
  }

  resolve_create_installer_path
  assert_eq "$CREATE_INSTALLER_PATH" "$discovered_app" "resolve create installer path uses discovered installer"
  rm -rf "$temp_root"
}

test_ensure_create_target_is_ready_same_version_skips() {
  CREATE_VOLUME="/Volumes/TestUSB"
  CREATE_APP_VERSION="14.6.1"
  CREATE_FORCE="no"

  detect_volume_installer_app() {
    printf '/Volumes/TestUSB/Install macOS Sonoma.app'
  }
  get_installer_short_ver() {
    printf '14.6.1'
  }

  local output=""
  set +e
  output="$(ensure_create_target_is_ready 2>&1)"
  local rc=$?
  set -e

  assert_eq "$rc" "1" "same installer version short-circuits create flow"
  assert_contains "$output" "SUCCESS:目标卷已是同版本可启动安装器" "same version path reports skip"
}

test_ensure_create_target_is_ready_requires_force_for_different_version() {
  CREATE_VOLUME="/Volumes/TestUSB"
  CREATE_APP_VERSION="14.6.1"
  CREATE_FORCE="no"

  detect_volume_installer_app() {
    printf '/Volumes/TestUSB/Install macOS Ventura.app'
  }
  get_installer_short_ver() {
    printf '13.6.7'
  }

  local output=""
  set +e
  output="$(ensure_create_target_is_ready 2>&1)"
  local rc=$?
  set -e

  assert_eq "$rc" "1" "different installer version without force fails fast"
  assert_contains "$output" "DIE:目标卷包含不同版本的安装器" "different version path asks for force"
}

test_sub_download_keeps_phase_order() {
  local calls=()
  prepare_download_context() { calls+=("prepare:$*"); }
  print_header() { calls+=("header:$1"); }
  check_existing_installer_before_download() { calls+=("check"); return 0; }
  run_installer_download() { calls+=("download"); }
  complete_installer_download() { calls+=("complete"); }

  sub_download --version 14.6.1 --force
  assert_eq "${calls[*]}" "prepare:--version 14.6.1 --force header:下载 macOS 安装器 check download complete" "sub download keeps expected phase order"
}

test_sub_create_keeps_phase_order() {
  local calls=()
  prepare_create_context() { calls+=("prepare:$*"); }
  print_header() { calls+=("header:$1"); }
  validate_create_prerequisites() { calls+=("validate"); }
  resolve_create_inputs() { calls+=("resolve"); }
  check_create_target_readiness() { calls+=("ready"); return 0; }
  acquire_create_lock_and_confirm() { calls+=("confirm"); }
  run_create_execution() { calls+=("execute"); }

  sub_create --volume /Volumes/TestUSB --version 14.6.1 -y
  assert_eq "${calls[*]}" "prepare:--volume /Volumes/TestUSB --version 14.6.1 -y header:制作 macOS USB 启动盘 validate resolve ready confirm execute" "sub create keeps expected phase order"
}

test_acquire_installer_lock_creates_real_dir() {
  # 端到端写入测试：acquire_installer_lock 应创建真实锁目录，
  # 且重复获取（并发场景）应通过 die 报错。
  local lock_key="guard-$$-$(date +%s)"
  SCRIPT_NAME="macos_installer_guard"
  local lock_dir="/tmp/${SCRIPT_NAME}.${lock_key}.lock"
  rm -rf "$lock_dir"

  acquire_installer_lock "$lock_key"
  [[ -d "$lock_dir" ]] || fail "lock directory created on disk"
  pass "lock directory created on disk"

  # 第二次获取同一 key 应失败（模拟并发）
  local die_called=false
  die() { die_called=true; }
  acquire_installer_lock "$lock_key" || true
  [[ "$die_called" == "true" ]] || fail "concurrent lock acquisition reports conflict"
  pass "concurrent lock acquisition reports conflict"

  rm -rf "$lock_dir"
}

test_detect_volume_installer_app_real_fs() {
  # 端到端写入测试：在临时目录构造模拟卷 + 安装器 app，
  # 验证 detect_volume_installer_app 能真实扫描到（非 mock）。
  # 重新加载 macos_installer_utils.sh 的真实实现，
  # 避免此前测试对 find_installer_app 等的 mock 残留。
  # shellcheck disable=SC1091
  source "$REPO_ROOT/maintain/lib/macos_installer_utils.sh"

  local vol_root
  vol_root="$(mktemp -d "${TMPDIR:-/tmp}/macos-installer-vol.XXXXXX")"
  mkdir -p "$vol_root/Install macOS Sonoma.app/Contents"
  printf 'fake-installer' > "$vol_root/Install macOS Sonoma.app/Contents/Info.plist"

  local found=""
  found="$(detect_volume_installer_app "$vol_root" || true)"
  assert_eq "$found" "$vol_root/Install macOS Sonoma.app" "detect_volume_installer_app scans real volume"

  # 空卷应返回空（无匹配时不报错）
  local empty_vol
  empty_vol="$(mktemp -d "${TMPDIR:-/tmp}/macos-installer-empty.XXXXXX")"
  local empty_result=""
  empty_result="$(detect_volume_installer_app "$empty_vol" || true)"
  assert_eq "$empty_result" "" "detect_volume_installer_app returns empty on blank volume"

  rm -rf "$vol_root" "$empty_vol"
}

main() {
  cd "$REPO_ROOT"

  test_should_skip_installer_download
  test_resolve_create_installer_path_uses_discovery
  test_ensure_create_target_is_ready_same_version_skips
  test_ensure_create_target_is_ready_requires_force_for_different_version
  test_sub_download_keeps_phase_order
  test_sub_create_keeps_phase_order
  test_acquire_installer_lock_creates_real_dir
  test_detect_volume_installer_app_real_fs

  printf '\nmacOS installer flow guard passed: %d\n' "$PASS_COUNT"
}

main "$@"
