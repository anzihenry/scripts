#!/bin/zsh
# filepath: tests/setup_runtime_guard.sh

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
  [[ "$actual" == "$expected" ]] || { printf 'expected: %s\nactual:   %s\n' "$expected" "$actual" >&2; fail "$name"; }
  pass "$name"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local name="$3"
  [[ "$haystack" == *"$needle"* ]] || { printf 'missing substring: %s\noutput: %s\n' "$needle" "$haystack" >&2; fail "$name"; }
  pass "$name"
}

info() { printf 'INFO:%s\n' "$*"; }
warning() { printf 'WARN:%s\n' "$*"; }
success() { printf 'SUCCESS:%s\n' "$*"; }
print_header() { printf 'HEADER:%s\n' "$1"; }
log_time_start() { printf 'TIME_START:%s|%s\n' "$1" "$2"; }
log_time_end() { printf 'TIME_END:%s|%s|%s\n' "$1" "$2" "${3:-ok}"; }
prepare_log_file_path() { printf '%s' "/tmp/$1"; }
enable_log_capture() { :; }
bh_reset_summary() { :; }
bh_print_summary() { printf 'SUMMARY:%s\n' "$1"; }
bh_install_packages() { return 0; }

# shellcheck disable=SC1091
source "$REPO_ROOT/setup/lib/setup_runtime.sh"

test_initialize_setup_context_prefers_config_dir() {
  local temp_root
  temp_root="$(mktemp -d "${TMPDIR:-/tmp}/setup-runtime-guard.XXXXXX")"
  SCRIPT_DIR="$REPO_ROOT/setup"
  MACOS_SCRIPTS_CONFIG_DIR="$temp_root/config"

  initialize_setup_context

  assert_eq "$SETUP_LOG_FILE" "/tmp/macos-setup.log" "initialize setup context prepares log file"
  assert_eq "$DEFAULT_BREW_CONFIG_FILE" "$REPO_ROOT/setup/brew.conf.sh" "initialize setup context sets default brew config path"
  assert_eq "$BREW_CONFIG_FILE" "$temp_root/config/brew.conf.sh" "initialize setup context prefers config dir brew config"

  rm -rf "$temp_root"
}

test_run_setup_workflow_order() {
  local calls=()
  precheck() { calls+=("precheck"); }
  ensure_xcode_cli_installed() { calls+=("xcode"); }
  configure_homebrew() { calls+=("brew"); }
  install_node() { calls+=("node"); }
  install_python() { calls+=("python"); }
  install_ruby() { calls+=("ruby"); }
  install_go() { calls+=("go"); }
  config_android_and_java() { calls+=("android"); }
  install_core_software() { calls+=("core"); }
  post_verification() { calls+=("verify"); }
  print_setup_completion() { calls+=("done"); }

  run_setup_workflow
  assert_eq "${calls[*]}" "precheck xcode brew node python ruby go android core verify done" "run setup workflow keeps expected execution order"
}

test_install_core_software_reports_failure() {
  # 恢复真实实现，避免被前一个 workflow 顺序测试里的 stub 覆盖。
  # shellcheck disable=SC1091
  source "$REPO_ROOT/setup/lib/setup_runtime.sh"

  local temp_root=""
  temp_root="$(mktemp -d "${TMPDIR:-/tmp}/setup-runtime-core.XXXXXX")"
  BREW_CONFIG_FILE="$temp_root/brew.conf.sh"
  cat > "$BREW_CONFIG_FILE" <<'EOF'
FORMULAE_DEV_TOOLS=(
  git
  node
)
CASKS_DEV_TOOLS=(
  iterm2
)
EOF

  local output=""
  local output_file=""
  output_file="$(mktemp "${TMPDIR:-/tmp}/setup-runtime-output.XXXXXX")"

  bh_reset_summary() { :; }
  bh_print_summary() { printf 'SUMMARY:%s\n' "$1"; }
  bh_install_packages() {
    [[ "$1" == "--formulae" ]] && return 1
    return 0
  }

  install_core_software > "$output_file"
  output="$(cat "$output_file")"
  rm -f "$output_file"
  rm -rf "$temp_root"
  assert_contains "$output" "HEADER:安装核心开发工具" "install core software prints header"
  assert_contains "$output" "SUMMARY:核心软件安装报告" "install core software prints summary"
  assert_contains "$output" "WARN:部分 Homebrew 包安装失败" "install core software warns on partial failure"
}

main() {
  cd "$REPO_ROOT"
  test_initialize_setup_context_prefers_config_dir
  test_run_setup_workflow_order
  test_install_core_software_reports_failure
  printf '\nSetup runtime guard passed: %d\n' "$PASS_COUNT"
}

main "$@"
