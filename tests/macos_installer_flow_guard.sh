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

main() {
  cd "$REPO_ROOT"

  test_should_skip_installer_download
  test_resolve_create_installer_path_uses_discovery
  test_ensure_create_target_is_ready_same_version_skips
  test_ensure_create_target_is_ready_requires_force_for_different_version

  printf '\nmacOS installer flow guard passed: %d\n' "$PASS_COUNT"
}

main "$@"
