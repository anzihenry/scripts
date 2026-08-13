#!/bin/zsh
# filepath: tests/maintain_runtime_guard.sh

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

info() { printf 'INFO:%s\n' "$*"; }
warning() { printf 'WARN:%s\n' "$*"; }
error() { printf 'ERROR:%s\n' "$*" >&2; }
print_header() { printf 'HEADER:%s\n' "$1"; }
print_code() { printf 'CODE:%s\n' "$1"; }
print_table_row() { printf 'TABLE:%s=%s\n' "$1" "$2"; }
print_step() { printf 'STEP:%s/%s %s\n' "$1" "$2" "$3"; }
success() { printf 'SUCCESS:%s\n' "$*"; }
log_time_start() { printf 'TIME_START:%s|%s\n' "$1" "$2"; }
log_time_end() { printf 'TIME_END:%s|%s|%s\n' "$1" "$2" "${3:-ok}"; }
log_fatal() {
  printf 'FATAL:%s\n' "$*" >&2
  return 1
}
confirm() { return 0; }
prepare_log_file_path() { printf '%s' "/tmp/$1"; }

# shellcheck disable=SC1091
source "$REPO_ROOT/maintain/lib/command_runtime.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/maintain/lib/brew_updater_args.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/maintain/lib/brew_updater_casks.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/maintain/lib/brew_updater_runtime.sh"

test_command_preview() {
  local preview
  preview="$(command_preview brew upgrade --cask visual-studio-code)"
  assert_eq "$preview" "brew upgrade --cask visual-studio-code" "command_preview joins args with spaces"
}

test_run_logged_command_dry_run() {
  local output=""
  local marker
  marker="$(mktemp "${TMPDIR:-/tmp}/maintain-runtime-marker.XXXXXX")"
  rm -f "$marker"

  DRY_RUN="true"
  fake_exec() {
    : > "$marker"
  }

  output="$(run_logged_command "执行假命令" fake_exec)"
  [[ ! -e "$marker" ]] || fail "run_logged_command dry-run skips execution"
  pass "run_logged_command dry-run skips execution"

  assert_contains "$output" "INFO:[dry-run] 执行假命令" "run_logged_command dry-run prints description"
  assert_contains "$output" "CODE:fake_exec" "run_logged_command dry-run prints command"
}

test_announce_brew_updater_context() {
  DRY_RUN="false"
  FORCE_CASKS="false"
  ERROR_LOG="/tmp/brew-update-errors.log"

  local output=""
  output="$(announce_brew_updater_context)"
  assert_contains "$output" "HEADER:Homebrew 维护工具" "announce context prints header"
  assert_contains "$output" "INFO:错误日志位置: $ERROR_LOG" "announce context prints error log"
}

test_run_formulae_upgrade_limits_brew_to_formulae() {
  DRY_RUN="true"

  local output=""
  output="$(run_formulae_upgrade)"
  assert_contains "$output" "CODE:brew upgrade --formula" "formulae upgrade dry-run limits brew upgrade to formulae"
}

test_excluded_cask_matching() {
  SCRIPT_DIR="$REPO_ROOT/maintain"
  initialize_brew_updater_context

  is_excluded_cask "feishu" || fail "excluded cask list matches exact cask"
  pass "excluded cask list matches exact cask"

  is_excluded_cask "microsoft-teams" || fail "excluded cask list matches regex cask"
  pass "excluded cask list matches regex cask"

  if is_excluded_cask "vlc"; then
    fail "excluded cask list leaves non-excluded cask upgradeable"
  fi
  pass "excluded cask list leaves non-excluded cask upgradeable"

  FORCE_CASKS="true"
  if is_excluded_cask "feishu"; then
    fail "force flag bypasses excluded cask list"
  fi
  pass "force flag bypasses excluded cask list"
}

test_run_cask_upgrades_skips_excluded_casks() {
  SCRIPT_DIR="$REPO_ROOT/maintain"
  initialize_brew_updater_context

  local calls=()
  local output=""
  local output_file
  output_file="$(mktemp "${TMPDIR:-/tmp}/maintain-cask-output.XXXXXX")"
  get_outdated_casks() {
    printf '%s\n' "feishu" "vlc" "lark"
  }
  run_cask_upgrade() {
    calls+=("$1")
  }

  run_cask_upgrades > "$output_file"
  output="$(cat "$output_file")"
  rm -f "$output_file"

  assert_eq "${calls[*]}" "vlc" "cask upgrades only run for non-excluded casks"
  assert_eq "${SKIPPED_CASKS[*]}" "feishu lark" "cask upgrades track skipped excluded casks"
  assert_contains "$output" "WARN:发现 3 个可更新 Cask，排除 2 个" "cask upgrades report excluded count"
}

test_run_brew_updater_workflow_skip_flags() {
  local calls=()
  local output=""
  local output_file
  output_file="$(mktemp "${TMPDIR:-/tmp}/maintain-runtime-output.XXXXXX")"

  run_homebrew_update() { calls+=("update"); }
  run_formulae_upgrade() { calls+=("formulae"); }
  run_cask_upgrades() { calls+=("casks"); }
  run_cleanup() { calls+=("cleanup"); }
  warning() { printf 'WARN:%s\n' "$*"; }

  SKIP_FORMULAE="true"
  SKIP_CASKS="true"
  SKIP_CLEANUP="true"

  run_brew_updater_workflow > "$output_file"
  output="$(cat "$output_file")"
  rm -f "$output_file"
  assert_eq "${calls[*]}" "update" "workflow only runs required step when all optional phases are skipped"
  assert_contains "$output" "WARN:已跳过 Formulae 更新" "workflow reports skipped formulae"
  assert_contains "$output" "WARN:已跳过 Cask 更新" "workflow reports skipped casks"
  assert_contains "$output" "WARN:已跳过缓存清理" "workflow reports skipped cleanup"
}

test_run_brew_updater_workflow_order() {
  local calls=()

  run_homebrew_update() { calls+=("update"); }
  run_optional_formulae_upgrade() { calls+=("formulae"); }
  run_optional_cask_upgrades() { calls+=("casks"); }
  run_optional_cleanup() { calls+=("cleanup"); }

  run_brew_updater_workflow
  assert_eq "${calls[*]}" "update formulae casks cleanup" "workflow keeps expected phase order"
}

test_outdated_casks_filters_blank_lines() {
  # 回归护栏：brew outdated 输出可能以空行开头（干净 runner 首次运行等），
  # 空行经 (@f) 分割会产生空 cask 名并导致 brew info 对空参数失败。
  # 用假 brew 输出含空行的列表，验证 get_outdated_casks 会过滤掉空行。
  # 重新加载真实实现，避免此前测试对 get_outdated_casks 的 mock 残留。
  # shellcheck disable=SC1091
  source "$REPO_ROOT/maintain/lib/brew_updater_casks.sh"

  local fakebin
  fakebin="$(mktemp -d "${TMPDIR:-/tmp}/maintain-fakebrew.XXXXXX")"
  cat > "$fakebin/brew" <<'EOF'
#!/bin/bash
# 模拟 brew outdated --cask --greedy：以空行开头，避免依赖真实 brew 状态
printf '\nvisual-studio-code\niterm2\n'
EOF
  chmod +x "$fakebin/brew"

  local orig_path="$PATH"
  PATH="$fakebin:$PATH"
  local result=""
  result="$(get_outdated_casks)"
  PATH="$orig_path"
  rm -rf "$fakebin"

  assert_eq "$result" "iterm2
visual-studio-code" "get_outdated_casks filters leading blank lines"
}

test_run_cask_upgrades_skips_blank_cask_entry() {
  # 即使上游传入含空行的列表，run_cask_upgrades 也不应把空 cask 交给 run_cask_upgrade
  SCRIPT_DIR="$REPO_ROOT/maintain"
  initialize_brew_updater_context

  local calls=()
  local output_file
  output_file="$(mktemp "${TMPDIR:-/tmp}/maintain-cask-blank.XXXXXX")"
  get_outdated_casks() {
    printf '\nfeishu\nvlc\nlark\n'
  }
  run_cask_upgrade() {
    calls+=("$1")
  }

  run_cask_upgrades > "$output_file" 2>&1
  rm -f "$output_file"

  assert_eq "${calls[*]}" "vlc" "blank cask entries are skipped before upgrade"
  assert_eq "${SKIPPED_CASKS[*]}" "feishu lark" "blank cask entries do not pollute skipped list"
}

test_append_brew_update_error_log_writes_real_file() {
  # 端到端写入测试：真实追加错误日志文件并校验内容与格式，
  # 防止 ERROR_LOG 路径/格式回归（延续 plist 真实写入测试思路）。
  local log_file
  log_file="$(mktemp "${TMPDIR:-/tmp}/maintain-brew-errors.XXXXXX.log")"
  ERROR_LOG="$log_file"

  append_brew_update_error_log "feishu" "Cask 不存在或已失效"
  append_brew_update_error_log "vlc" "brew upgrade --cask 执行失败"

  [[ -f "$log_file" ]] || fail "error log file created on disk"
  pass "error log file created on disk"

  local content
  content="$(<"$log_file")"
  assert_contains "$content" "feishu" "first cask name recorded"
  assert_contains "$content" "Cask 不存在或已失效" "first failure message recorded"
  assert_contains "$content" "vlc" "second cask appended (not overwritten)"
  assert_contains "$content" "brew upgrade --cask 执行失败" "second failure message recorded"

  # 每行都应包含时间戳 + 更新失败标记
  local line_count
  line_count="$(grep -c "更新失败" "$log_file")"
  assert_eq "$line_count" "2" "each failure produces one log line"

  rm -f "$log_file"
}

main() {
  cd "$REPO_ROOT"

  test_command_preview
  test_run_logged_command_dry_run
  test_announce_brew_updater_context
  test_run_formulae_upgrade_limits_brew_to_formulae
  test_excluded_cask_matching
  test_run_cask_upgrades_skips_excluded_casks
  test_run_brew_updater_workflow_skip_flags
  test_run_brew_updater_workflow_order
  test_outdated_casks_filters_blank_lines
  test_run_cask_upgrades_skips_blank_cask_entry
  test_append_brew_update_error_log_writes_real_file

  printf '\nMaintain runtime guard passed: %d\n' "$PASS_COUNT"
}

main "$@"
