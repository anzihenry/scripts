#!/bin/zsh
# filepath: tests/regression_guard.sh
# 针对已修复缺陷的回归护栏：直接执行真实实现，不把被测函数桩掉。
#
# 覆盖（每条都对应一个曾经在 main 上真实存在的缺陷）：
#   1. lib/colors.sh 的 info/success/warning/error 必须写 stderr
#      —— 写 stdout 会污染 $(...) 返回值（job create --disabled 失效、
#      job_paths 错误信息被吞）
#   2. setup/lib/setup_runtime.sh 成功路径不得返回非零（tail 位置 && 缺陷）
#   3. job/lib/job_plist.sh 校验失败必须保留原文件、不留临时文件
#   4. maintain/lib/macos_installer_flow.sh 陈旧锁必须能自动接管
#   5. maintain/lib/release_publish_flow.sh release_status 三态语义
#   6. lib/utils.sh first_line 不引入 | head 的 SIGPIPE 风险

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS_COUNT=0

pass() { printf '[PASS] %s\n' "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { printf '[FAIL] %s\n' "$1" >&2; exit 1; }

assert_eq() {
  local actual="$1" expected="$2" name="$3"
  [[ "$actual" == "$expected" ]] || {
    printf 'expected: %s\nactual:   %s\n' "$expected" "$actual" >&2
    fail "$name"
  }
  pass "$name"
}

assert_contains() {
  local haystack="$1" needle="$2" name="$3"
  [[ "$haystack" == *"$needle"* ]] || {
    printf 'missing substring: %s\noutput: %s\n' "$needle" "$haystack" >&2
    fail "$name"
  }
  pass "$name"
}

assert_not_contains() {
  local haystack="$1" needle="$2" name="$3"
  [[ "$haystack" != *"$needle"* ]] || {
    printf 'unexpected substring: %s\noutput: %s\n' "$needle" "$haystack" >&2
    fail "$name"
  }
  pass "$name"
}

# ===== 1. 日志函数必须写 stderr =====
test_log_functions_write_stderr() {
  local stdout_file stderr_file stdout_file2

  # 不依赖 colors.sh 的 TTY 检测：显式固定为无颜色输出
  NO_COLOR=true
  FORCE_COLOR=false
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/colors.sh"

  stdout_file="$(mktemp "${TMPDIR:-/tmp}/regression-stdout.XXXXXX")"
  stderr_file="$(mktemp "${TMPDIR:-/tmp}/regression-stderr.XXXXXX")"

  warning "警告文本" > "$stdout_file" 2> "$stderr_file"
  assert_eq "$(cat "$stdout_file")" "" "warning 不写 stdout"
  assert_contains "$(cat "$stderr_file")" "警告文本" "warning 写 stderr"

  info "信息文本" > "$stdout_file" 2> "$stderr_file"
  assert_eq "$(cat "$stdout_file")" "" "info 不写 stdout"
  assert_contains "$(cat "$stderr_file")" "信息文本" "info 写 stderr"

  error "错误文本" > "$stdout_file" 2> "$stderr_file"
  assert_eq "$(cat "$stdout_file")" "" "error 不写 stdout"
  assert_contains "$(cat "$stderr_file")" "错误文本" "error 写 stderr"

  success "成功文本" > "$stdout_file" 2> "$stderr_file"
  assert_eq "$(cat "$stdout_file")" "" "success 不写 stdout"
  assert_contains "$(cat "$stderr_file")" "成功文本" "success 写 stderr"

  # 关键回归：命令替换只应拿到函数自身输出，不能被日志文本污染
  local captured
  captured="$(warning "不应被捕获" 2> /dev/null; printf '1')"
  assert_eq "$captured" "1" "命令替换不被 warning 污染（--disabled 回归）"

  # print_header 等面向用户的输出仍应走 stdout
  stdout_file2="$(mktemp "${TMPDIR:-/tmp}/regression-stdout2.XXXXXX")"
  print_header "标题" > "$stdout_file2" 2> /dev/null
  assert_contains "$(cat "$stdout_file2")" "标题" "print_header 保持 stdout"

  rm -f "$stdout_file" "$stderr_file" "$stdout_file2"
  return 0
}

# ===== 2. setup 预检成功路径不得返回非零 =====
test_setup_precheck_success_path() {
  local sandbox
  sandbox="$(mktemp -d "${TMPDIR:-/tmp}/regression-setup.XXXXXX")"
  mkdir -p "$sandbox/config"
  printf 'FORMULAE_DEV=()\n' > "$sandbox/brew.conf.sh"

  local rc=0
  (
    NO_COLOR=true
    SCRIPT_DIR="$sandbox"
    MACOS_SCRIPTS_CONFIG_DIR="$sandbox/config"
    MACOS_SCRIPTS_LOG_DIR="$sandbox/logs"
    # 桩掉与真实机器相关的检查，聚焦「成功路径返回值」
    require_macos_min_version() { return 0; }
    check_network_reachability() { return 0; }
    require_command() { return 0; }

    # shellcheck disable=SC1091
    source "$REPO_ROOT/lib/colors.sh"
    # shellcheck disable=SC1091
    source "$REPO_ROOT/lib/utils.sh"
    # 日志写入沙箱，避免污染仓库或真实 HOME
    SETUP_LOG_FILE="$sandbox/logs/setup.log"
    prepare_log_file_path() { printf '%s' "$SETUP_LOG_FILE"; }
    enable_log_capture() { return 0; }
    # shellcheck disable=SC1091
    source "$REPO_ROOT/setup/lib/setup_runtime.sh"

    initialize_setup_context
    ensure_setup_brew_config_ready || exit 1
    verify_setup_platform_requirements || exit 1
    exit 0
  ) || rc=$?

  rm -rf "$sandbox"
  assert_eq "$rc" "0" "setup 预检成功路径返回 0（tail 位置缺陷回归）"
  return 0
}

# ===== 2b. setup 脚本在 set -u 下不得引用未定义变量（BOLD/NC） =====
test_setup_scripts_no_unbound_vars() {
  # setup/*.sh 已启用 set -u；历史上 ${BOLD} 从未定义，一旦开启 set -u
  # 就会在 print_setup_completion 处直接报 parameter not set。
  local out_file err_file
  out_file="$(mktemp "${TMPDIR:-/tmp}/regression-bold-out.XXXXXX")"
  err_file="$(mktemp "${TMPDIR:-/tmp}/regression-bold-err.XXXXXX")"

  local rc=0
  (
    set -euo pipefail
    # shellcheck disable=SC1091
    source "$REPO_ROOT/lib/colors.sh"
    # shellcheck disable=SC1091
    source "$REPO_ROOT/lib/utils.sh"
    # shellcheck disable=SC1091
    source "$REPO_ROOT/setup/lib/setup_postcheck.sh"

    print_header() { :; }
    highlight() { printf '%s' "$*"; }
    BREW_CONFIG_FILE="/tmp/regression.conf"
    SETUP_LOG_FILE="/tmp/regression.log"
    print_setup_completion
  ) > "$out_file" 2> "$err_file" || rc=$?

  [[ $rc -eq 0 ]] || {
    printf 'print_setup_completion failed (rc=%d):\n%s\n' "$rc" "$(cat "$err_file")" >&2
    rm -f "$out_file" "$err_file"
    fail "setup 完成提示在 set -u 下可正常渲染"
  }
  pass "setup 完成提示在 set -u 下可正常渲染"
  assert_not_contains "$(cat "$err_file")" "parameter not set" "无未定义变量报错（BOLD 回归）"

  rm -f "$out_file" "$err_file"
  return 0
}

# ===== 3. plist 原子写入 =====
test_plist_atomic_write() {
  local sandbox target
  sandbox="$(mktemp -d "${TMPDIR:-/tmp}/regression-plist.XXXXXX")"
  target="$sandbox/test.plist"
  printf 'ORIGINAL' > "$target"

  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/colors.sh"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/job/lib/job_plist.sh"

  local rc=0
  write_plist_file "$target" "this is not a plist" > /dev/null 2>&1 || rc=$?
  [[ $rc -ne 0 ]] || fail "非法 plist 应写入失败"
  pass "非法 plist 被拒绝"
  assert_eq "$(cat "$target")" "ORIGINAL" "校验失败保留原文件"
  assert_eq "$(find "$sandbox" -name '*.tmp.*' | wc -l | tr -d ' ')" "0" "失败后不留临时文件"

  local valid_plist
  valid_plist='<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>Label</key><string>com.test.regression</string></dict></plist>'

  write_plist_file "$target" "$valid_plist" > /dev/null 2>&1
  plutil -lint "$target" > /dev/null 2>&1 || fail "合法 plist 应写入成功"
  pass "合法 plist 写入成功"
  assert_eq "$(find "$sandbox" -name '*.tmp.*' | wc -l | tr -d ' ')" "0" "成功写入后不留临时文件"

  rm -rf "$sandbox"
  return 0
}

# ===== 4. 陈旧锁自动接管 =====
test_installer_stale_lock_takeover() {
  SCRIPT_NAME="regression_guard_$$"
  INSTALLER_LOCK_DIRS=()

  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/colors.sh"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/maintain/lib/macos_installer_utils.sh"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/maintain/lib/macos_installer_flow.sh"

  die() { log_fatal "$@"; }

  local lock_dir="/tmp/${SCRIPT_NAME}.stale.lock"
  rm -rf "$lock_dir"
  mkdir -p "$lock_dir"
  # 一个几乎不可能存在的 PID -> 判定为陈旧
  printf '999999' > "$lock_dir/pid"

  acquire_installer_lock "stale" > /dev/null 2>&1 || {
    rm -rf "$lock_dir"
    fail "陈旧锁应被自动接管"
  }
  pass "陈旧锁被自动接管"
  assert_eq "$(cat "$lock_dir/pid")" "$$" "接管后写入当前 PID"

  rm -rf "$lock_dir"

  # 无 pid 文件（旧版遗留）应保守拒绝，避免误删他人锁
  mkdir -p "$lock_dir"
  local rc=0
  ( acquire_installer_lock "stale" ) > /dev/null 2>&1 || rc=$?
  [[ $rc -ne 0 ]] || fail "无 pid 的锁应保守拒绝"
  pass "无 pid 文件的锁保守拒绝"
  rm -rf "$lock_dir"
  return 0
}

# ===== 5. release_status 三态语义 =====
test_release_status_three_states() {
  local sandbox
  sandbox="$(mktemp -d "${TMPDIR:-/tmp}/regression-release.XXXXXX")"

  mkgh() { # $1 = stderr 文本, $2 = 退出码
    local dir="$1" text="$2" code="$3"
    mkdir -p "$dir"
    {
      printf '#!/bin/bash\n'
      printf 'echo %q >&2\n' "$text"
      printf 'exit %s\n' "$code"
    } > "$dir/gh"
    chmod +x "$dir/gh"
  }

  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/colors.sh"
  TAG="v9.9.9"
  REPO_SLUG="anzihenry/scripts"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/maintain/lib/release_publish_flow.sh"

  local ghdir rc

  ghdir="$sandbox/notfound"
  mkgh "$ghdir" "gh: Not Found (HTTP 404)" 1
  rc=0
  PATH="$ghdir:$PATH" release_status > /dev/null 2>&1 || rc=$?
  assert_eq "$rc" "1" "404 判定为确定不存在"

  ghdir="$sandbox/error"
  mkgh "$ghdir" "gh: API rate limit exceeded (HTTP 403)" 1
  rc=0
  PATH="$ghdir:$PATH" release_status > /dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "限流/网络错误判定为查询失败"

  ghdir="$sandbox/ok"
  mkgh "$ghdir" "" 0
  rc=0
  PATH="$ghdir:$PATH" release_status > /dev/null 2>&1 || rc=$?
  assert_eq "$rc" "0" "存在判定为 0"

  # 查询失败时不得走 create（避免在状态未知时误创建）
  ghdir="$sandbox/error"
  UPDATE_EXISTING="false"
  TITLE="t"
  TARGET="main"
  NOTES_FILE="/tmp/notes.md"
  local output
  rc=0
  output="$(PATH="$ghdir:$PATH" create_or_update_release 2>&1)" || rc=$?
  [[ $rc -ne 0 ]] || fail "查询失败时 create_or_update_release 必须中止"
  pass "查询失败时中止发布"
  assert_not_contains "$output" "gh release create" "查询失败时不执行 create"

  rm -rf "$sandbox"
  return 0
}

# ===== 6. first_line 不引入 SIGPIPE =====
test_first_line_helper() {
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/utils.sh"

  multi_line_output() {
    printf 'first\nsecond\nthird\n'
  }

  assert_eq "$(first_line multi_line_output)" "first" "first_line 只取首行"

  # 生产代码中不应再出现 `| head`（pipefail 下的 SIGPIPE 隐患）。
  # 先剔除注释行，避免命中说明文字。
  # 注意：grep 无命中时返回 1，在 set -e 下会让赋值语句直接终止脚本，
  # 因此这里显式关闭 errexit 再取结果。
  local hits
  set +e
  hits="$(grep -rn '| *head' "$REPO_ROOT/lib" "$REPO_ROOT/setup" "$REPO_ROOT/maintain" \
    "$REPO_ROOT/job" "$REPO_ROOT/bin" "$REPO_ROOT/bootstrap" \
    --include='*.sh' 2> /dev/null)" || true
  set -e
  hits="$(printf '%s\n' "$hits" | grep -v 'tests/' | grep -vE ':[0-9]+: *#|:[0-9]+: *//')" || true
  local hit_count=0
  [[ -z "$hits" ]] || hit_count="$(printf '%s\n' "$hits" | wc -l | tr -d ' ')"
  assert_eq "$hit_count" "0" "生产代码不再使用 | head（注释除外）"

  # 显式返回 0：上面的 grep 管道在无命中时以非零结束，
  # 若作为函数末位状态会让 set -e 把整个 guard 判为失败。
  return 0
}

main() {
  cd "$REPO_ROOT"

  test_log_functions_write_stderr
  test_setup_precheck_success_path
  test_setup_scripts_no_unbound_vars
  test_plist_atomic_write
  test_installer_stale_lock_takeover
  test_release_status_three_states
  test_first_line_helper

  printf '\nRegression guard passed: %d\n' "$PASS_COUNT"
}

main "$@"
