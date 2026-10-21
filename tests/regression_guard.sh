#!/bin/zsh
# filepath: tests/regression_guard.sh
# 针对已修复缺陷的回归护栏：直接执行真实实现，不把被测函数桩掉。
#
# 覆盖已修缺陷与共享日志行为：
#   1. lib/colors.sh 的 info/success/warning/error 必须写 stderr
#      —— 写 stdout 会污染 $(...) 返回值
#   2. setup/lib/setup_runtime.sh 成功路径不得返回非零（tail 位置 && 缺陷）
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
  assert_eq "$captured" "1" "命令替换不被 warning 污染"

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
    check_network_reachability() { return 0; }
    require_command() { return 0; }

    # shellcheck disable=SC1091
    source "$REPO_ROOT/lib/colors.sh"
    # shellcheck disable=SC1091
    source "$REPO_ROOT/lib/utils.sh"
    require_supported_macos() { return 0; }
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
      printf '#!/bin/zsh\n'
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

  # gh api 对缺失 release 的真实文案变体（大小写/位置不同）也必须识别为不存在
  ghdir="$sandbox/notfound-lower"
  mkgh "$ghdir" '{"message":"Not Found"}' 1
  rc=0
  PATH="$ghdir:$PATH" release_status > /dev/null 2>&1 || rc=$?
  assert_eq "$rc" "1" "JSON message not found 亦判定为不存在"

  ghdir="$sandbox/error"
  mkgh "$ghdir" "gh: API rate limit exceeded (HTTP 403)" 1
  rc=0
  PATH="$ghdir:$PATH" release_status > /dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "限流判定为查询失败"

  # 401/5xx 同样属于「状态未知」，不得误判为不存在
  ghdir="$sandbox/auth"
  mkgh "$ghdir" "gh: Bad credentials (HTTP 401)" 1
  rc=0
  PATH="$ghdir:$PATH" release_status > /dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "鉴权失败判定为查询失败"

  ghdir="$sandbox/server"
  mkgh "$ghdir" "gh: Server Error (HTTP 502)" 1
  rc=0
  PATH="$ghdir:$PATH" release_status > /dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "5xx 判定为查询失败"

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
test_unified_log_paths() {
  local sandbox result rc=0
  sandbox="$(mktemp -d "${TMPDIR:-/tmp}/regression-logs.XXXXXX")"
  sandbox="${sandbox:A}"
  result="$(HOME="$sandbox/home" env -u MACOS_SCRIPTS_LOG_DIR /bin/zsh -c 'source "$1"; prepare_log_file_path bootstrap.log' -- "$REPO_ROOT/lib/utils.sh")"
  assert_eq "$result" "$sandbox/home/Library/Logs/macos-scripts/bootstrap.log" "未设置日志目录时使用统一默认目录"
  result="$(HOME="$sandbox/home" MACOS_SCRIPTS_LOG_DIR='' /bin/zsh -c 'source "$1"; prepare_log_file_path homebrew-setup.log' -- "$REPO_ROOT/lib/utils.sh")"
  assert_eq "$result" "$sandbox/home/Library/Logs/macos-scripts/homebrew-setup.log" "空日志目录也使用统一默认目录"
  result="$(MACOS_SCRIPTS_LOG_DIR="$sandbox/custom logs/" /bin/zsh -c 'source "$1"; prepare_log_file_path brew_update_errors.log' -- "$REPO_ROOT/lib/utils.sh")"
  assert_eq "$result" "$sandbox/custom logs/brew_update_errors.log" "自定义目录支持空格和尾部斜杠"
  [[ ! -e "$result" ]] || fail "准备错误日志路径不应提前创建错误日志"
  pass "成功维护时不提前创建错误日志"

  printf 'blocked\n' > "$sandbox/blocked"
  result="$(MACOS_SCRIPTS_LOG_DIR="$sandbox/blocked/logs" /bin/zsh -c 'source "$1"; prepare_log_file_path test.log' -- "$REPO_ROOT/lib/utils.sh" 2>&1)" || rc=$?
  [[ "$rc" -ne 0 ]] || fail "日志目录不可创建时必须失败"
  pass "日志目录不可创建时返回非零"
  assert_contains "$result" '日志目录不可用' "日志目录错误给出明确提示"

  mkdir "$sandbox/custom logs/occupied.log"
  rc=0
  result="$(MACOS_SCRIPTS_LOG_DIR="$sandbox/custom logs" /bin/zsh -c 'source "$1"; prepare_log_file_path occupied.log' -- "$REPO_ROOT/lib/utils.sh" 2>&1)" || rc=$?
  [[ "$rc" -ne 0 ]] || fail "日志文件被目录占用时必须失败"
  pass "日志文件无效时返回非零"
  assert_contains "$result" '日志文件不可写' "日志文件错误不静默回退"

  HOME="$sandbox/direct-home" env -u MACOS_SCRIPTS_LOG_DIR /bin/zsh "$REPO_ROOT/setup/homebrew-setup.sh" --help > "$sandbox/direct-output" 2>&1
  [[ ! -e "$sandbox/direct-home" ]] || fail "直接运行帮助不应创建用户目录"
  pass "直接运行 setup 帮助不创建日志目录"
  HOME="$sandbox/bootstrap-home" env -u MACOS_SCRIPTS_LOG_DIR /bin/zsh "$REPO_ROOT/bootstrap/install.sh" --help > "$sandbox/bootstrap-output" 2>&1
  [[ ! -e "$sandbox/bootstrap-home" ]] || fail "bootstrap 帮助不应创建用户目录"
  pass "独立 bootstrap 帮助不创建日志目录"

  rc=0
  MACOS_SCRIPTS_LOG_DIR="$sandbox/blocked/logs" /bin/zsh "$REPO_ROOT/setup/homebrew-setup.sh" --help > "$sandbox/blocked-output" 2>&1 || rc=$?
  assert_eq "$rc" 0 "日志目录无效时仍可查看帮助"
  rc=0
  MACOS_SCRIPTS_LOG_DIR="$sandbox/blocked/logs" /bin/zsh "$REPO_ROOT/setup/homebrew-setup.sh" --dry-run > "$sandbox/blocked-output" 2>&1 || rc=$?
  [[ "$rc" -ne 0 ]] || fail "执行入口仍应检查日志目录"
  pass "真正执行时日志目录无效仍中止"
  rm -rf "$sandbox"
}

test_log_run_headers() {
  local sandbox result
  sandbox="$(mktemp -d "${TMPDIR:-/tmp}/regression-log-headers.XXXXXX")"
  cat > "$sandbox/log-runner.sh" <<'RUNNER'
#!/bin/zsh
set -euo pipefail
source "$HEADER_TEST_UTILS"
enable_log_capture "$HEADER_TEST_LOG" "$(get_log_run_mode "$@")"
printf 'BODY\n'
RUNNER
  local log_file="$sandbox/combined.log"
  result="$(HEADER_TEST_UTILS="$REPO_ROOT/lib/utils.sh" HEADER_TEST_LOG="$log_file" /bin/zsh "$sandbox/log-runner.sh" --title --dry-run)"
  result="$(<"$log_file")"
  assert_contains "$result" '脚本: log-runner.sh' "运行头记录真实脚本名称"
  assert_contains "$result" '模式: 实际执行' "参数值中的 --dry-run 不误标执行模式"
  [[ "$result" =~ '开始时间: [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} [+-][0-9]{4}' ]] || fail "运行头应记录带时区的开始时间"
  pass "运行头记录带时区的开始时间"
  [[ "$result" =~ 'PID: [0-9]+' ]] || fail "运行头应记录 PID"
  pass "运行头记录 PID"

  result="$(HEADER_TEST_UTILS="$REPO_ROOT/lib/utils.sh" HEADER_TEST_LOG="$log_file" /bin/zsh "$sandbox/log-runner.sh" --title secret-header-sentinel --dry-run)"
  result="$(<"$log_file")"
  assert_eq "$(grep -c '^===== 运行开始 =====$' "$log_file")" 2 "重复运行追加分隔而不覆盖旧日志"
  assert_eq "$(grep -c '^BODY$' "$log_file")" 2 "重复运行保留两次原始输出"
  assert_contains "$result" '模式: dry-run' "真正的 dry-run 开关正确标记"
  assert_not_contains "$result" secret-header-sentinel "运行头不记录完整参数或敏感参数值"
  rm -rf "$sandbox"
}

test_log_rotation() {
  setopt localoptions no_bg_nice
  local sandbox log_file payload result candidate rc=0
  sandbox="$(mktemp -d "${TMPDIR:-/tmp}/regression-rotation.XXXXXX")"
  source "$REPO_ROOT/lib/logging.sh"
  local MACOS_SCRIPTS_LOG_MAX_BYTES=16 MACOS_SCRIPTS_LOG_BACKUPS=2 MACOS_SCRIPTS_LOG_RETENTION_DAYS=30
  log_file="$sandbox/run.log"
  payload='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
  ml_log_policy
  ml_locked_write "$log_file" '' true
  result="$(printf '%s' "$payload" | ml_stream_log "$log_file")"
  assert_eq "$result" "$payload" "轮转不截断终端输出（长行无换行）"
  assert_eq "$(cat "$log_file.2" "$log_file.1" "$log_file")" "${payload[17,-1]}" "按归档数量保留最近日志且顺序不变"
  for candidate in "$log_file" "$log_file".[0-9]*(N); do
    (( $(stat -f '%z' "$candidate") <= 16 )) || fail "日志文件超过单文件大小上限"
  done
  pass "长运行中当前文件及归档均不超上限"
  [[ ! -e "$log_file.3" ]] || fail "超出数量的归档未删除"
  pass "归档数量受到限制"

  printf 'expired' > "$log_file.2"
  touch -t 200001010000 "$log_file.2"
  printf 'extra' > "$log_file.9"
  printf 'keep' > "$log_file.notes"
  ml_append_log "$log_file" ''
  [[ ! -e "$log_file.2" && ! -e "$log_file.9" ]] || fail "过期或超出份数的归档未清理"
  pass "自动清理过期和超出份数的归档"
  assert_eq "$(<"$log_file.notes")" keep "清理不影响非归档文件"

  log_file="$sandbox/oversized.log"
  printf '%s' "$payload" > "$log_file"
  ml_append_log "$log_file" Z
  assert_eq "$(<"$log_file.1")" "${payload[-16,-1]}" "接管旧大日志时保留末尾预算内容"
  assert_eq "$(<"$log_file")" Z "旧大日志轮转后正常记录新内容"

  MACOS_SCRIPTS_LOG_MAX_BYTES=5
  MACOS_SCRIPTS_LOG_BACKUPS=10
  payload='中文🙂无换行'
  log_file="$sandbox/unicode.log"
  ml_log_policy
  result="$(printf '%s' "$payload" | ml_stream_log "$log_file")"
  assert_eq "$result" "$payload" "UTF-8 终端输出保持原样"
  result=""
  for candidate in "$log_file".[0-9]*(NOn); do result+="$(<"$candidate")"; done
  result+="$(<"$log_file")"
  assert_eq "$result" "$payload" "按字节拆分归档后仍可完整重组 UTF-8"

  MACOS_SCRIPTS_LOG_MAX_BYTES=16
  MACOS_SCRIPTS_LOG_BACKUPS=20
  log_file="$sandbox/concurrent.log"
  ml_append_log "$log_file" ''
  local letters_a='' letters_b=''
  letters_a="${(l:80::A:)letters_a}"
  letters_b="${(l:80::B:)letters_b}"
  ml_append_log "$log_file" "$letters_a" &
  local first_writer=$!
  ml_append_log "$log_file" "$letters_b" &
  local second_writer=$!
  wait "$first_writer"
  wait "$second_writer"
  result="$(cat "$log_file".[0-9]*(N) "$log_file")"
  assert_eq "${#result}" 160 "并发写入及轮转不丢失内容"
  assert_eq "$(printf '%s' "$result" | tr -cd A | wc -c | tr -d ' ')" 80 "并发写入保留第一份输出"
  assert_eq "$(printf '%s' "$result" | tr -cd B | wc -c | tr -d ' ')" 80 "并发写入保留第二份输出"

  printf 'private' > "$sandbox/target"
  ln -s "$sandbox/target" "$sandbox/link.log"
  ml_append_log "$sandbox/link.log" bad 2>/dev/null || rc=$?
  [[ "$rc" -ne 0 ]] || fail "日志符号链接应拒绝写入"
  pass "拒绝跟随日志符号链接"
  assert_eq "$(<"$sandbox/target")" private "符号链接目标保持不变"
  MACOS_SCRIPTS_LOG_MAX_BYTES=0
  rc=0
  ml_append_log "$sandbox/invalid.log" bad 2>/dev/null || rc=$?
  [[ "$rc" -ne 0 && ! -e "$sandbox/invalid.log" ]] || fail "非法轮转参数应在写入前失败"
  pass "非法轮转参数在写入前失败"

  awk '/^# BEGIN STANDALONE LOGGING$/ { active=1; next } /^# END STANDALONE LOGGING$/ { exit } active { print }' "$REPO_ROOT/bootstrap/install.sh" > "$sandbox/embedded"
  sed '1,2d' "$REPO_ROOT/lib/logging.sh" > "$sandbox/shared"
  cmp -s "$sandbox/embedded" "$sandbox/shared" || fail "独立 bootstrap 日志实现与公共库不同步"
  pass "独立 bootstrap 与公共轮转实现保持一致"
  rm -rf "$sandbox"
}

test_xcode_no_check_compatibility() {
  local result
  result="$(/bin/zsh -c '
    source "$1/lib/utils.sh"
    xcode-select() { [[ "$1" == -p ]]; }
    xcrun() { exit 99; }
    ensure_xcode_cli_installed --no-check
  ' zsh "$REPO_ROOT" 2>&1)"
  assert_contains "$result" 'Xcode 命令行工具已就绪' "--no-check 保留仅检查工具路径的兼容行为"
}

test_macos_version_policy() {
  local sandbox result rc version entry
  sandbox="$(mktemp -d "${TMPDIR:-/tmp}/regression-platform.XXXXXX")"
  mkdir -p "$sandbox/bin" "$sandbox/home"
  cat > "$sandbox/bin/sw_vers" <<'SHIM'
#!/bin/zsh
[[ "${MACOS_TEST_VERSION}" != failed ]] || exit 1
printf '%s\n' "$MACOS_TEST_VERSION"
SHIM
  local command_name
  for command_name in brew curl git xcode-select xcrun softwareupdate sudo diskutil ssh-keygen gh; do
    cat > "$sandbox/bin/$command_name" <<'SHIM'
#!/bin/zsh
printf '%s\n' "$0 $*" >> "$MACOS_TEST_CALLS"
exit 91
SHIM
  done
  chmod +x "$sandbox/bin/"*
  local HOME="$sandbox/home" MACOS_SCRIPTS_CONFIG_DIR="$sandbox/config" MACOS_SCRIPTS_LOG_DIR="$sandbox/logs"
  local PATH="$sandbox/bin:$PATH" MACOS_TEST_VERSION MACOS_TEST_CALLS="$sandbox/calls"
  export HOME PATH MACOS_SCRIPTS_CONFIG_DIR MACOS_SCRIPTS_LOG_DIR MACOS_TEST_VERSION MACOS_TEST_CALLS
  for version in 10.15.7 13.7.8 14.0 14.7.1 15.0 26.1 '' nonsense 14.bad failed; do
    MACOS_TEST_VERSION="$version"
    rc=0
    result="$(/bin/zsh -c 'source "$1/lib/utils.sh"; require_supported_macos' zsh "$REPO_ROOT" 2>&1)" || rc=$?
    case "$version" in
      14.0|14.7.1|15.0|26.1) assert_eq "$rc" 0 "支持 macOS $version" ;;
      *) [[ "$rc" -ne 0 ]] || fail "版本 $version 应拒绝"; pass "拒绝不支持或无法识别的版本：${version:-空}" ;;
    esac
  done
  MACOS_TEST_VERSION=13.7.8
  local -a args
  for entry in bootstrap/install.sh setup/homebrew-setup.sh setup/macos-setup.sh setup/ohmyzsh-setup.sh setup/git_forge_ssh_setup.sh maintain/formulaes_casks_updater.sh maintain/github_release_publish.sh maintain/macos_sys_usb_maker.sh lint/lint_shell.sh; do
    args=()
    [[ "$entry" != maintain/macos_sys_usb_maker.sh ]] || args=(list)
    rc=0
    result="$(/bin/zsh "$REPO_ROOT/$entry" "${args[@]}" </dev/null 2>&1)" || rc=$?
    [[ "$rc" -ne 0 ]] || fail "$entry 应拒绝旧系统"
    assert_contains "$result" '仅支持 macOS 14' "$entry 在执行前检查系统版本"
    result="$(/bin/zsh "$REPO_ROOT/$entry" --help 2>&1)" || fail "$entry 旧系统帮助应可用"
    assert_contains "$result" '用法' "$entry 旧系统可查看帮助"
  done
  for entry in download create; do
    rc=0
    args=()
    [[ "$entry" != download ]] || args=(--version 14.6.1)
    result="$(/bin/zsh "$REPO_ROOT/maintain/macos_sys_usb_maker.sh" "$entry" "${args[@]}" 2>&1)" || rc=$?
    [[ "$rc" -ne 0 ]] || fail "installer $entry 应拒绝旧系统"
    assert_contains "$result" '仅支持 macOS 14' "installer $entry 在获取锁和外部操作前检查版本"
    result="$(/bin/zsh "$REPO_ROOT/maintain/macos_sys_usb_maker.sh" "$entry" --help 2>&1)" || fail "installer $entry 帮助应可用"
  done
  rc=0
  result="$(cd "$sandbox"; /bin/zsh -s -- --dry-run --yes < "$REPO_ROOT/bootstrap/install.sh" 2>&1)" || rc=$?
  [[ "$rc" -ne 0 ]] || fail "管道入口应拒绝旧系统"
  assert_contains "$result" '仅支持 macOS 14' "独立管道入口执行相同的系统检查"
  result="$(/bin/zsh "$REPO_ROOT/bin/macos-scripts" version)"
  assert_contains "$result" 'macos-scripts v' "旧系统仍可查询 CLI 版本"
  result="$(/bin/zsh "$REPO_ROOT/bin/macos-scripts" setup brew configure --help)"
  assert_contains "$result" '用法' "旧系统仍可查看 CLI 子命令帮助"
  [[ ! -e "$MACOS_TEST_CALLS" ]] || fail "旧系统不应调用安装、网络或配置命令：$(<"$MACOS_TEST_CALLS")"
  pass "所有旧系统入口在外部操作前中止"
  [[ ! -e "$sandbox/config/brew.conf.sh" && ! -e "$HOME/.zshrc" && ! -e "$HOME/.ssh" ]] || fail "旧系统不应创建配置"
  pass "旧系统不创建用户配置或 SSH 密钥"
  awk '/^# BEGIN MACOS REQUIREMENT$/ { active=1; next } /^# END MACOS REQUIREMENT$/ { exit } active { print }' "$REPO_ROOT/bootstrap/install.sh" > "$sandbox/embedded"
  awk '/^# BEGIN MACOS REQUIREMENT$/ { active=1; next } /^# END MACOS REQUIREMENT$/ { exit } active { print }' "$REPO_ROOT/lib/utils.sh" > "$sandbox/shared"
  cmp -s "$sandbox/embedded" "$sandbox/shared" || fail "独立版本检查与公共实现不同步"
  pass "独立 bootstrap 与公共版本检查保持一致"
  rm -rf "$sandbox"
}

test_log_capture_exit_and_links() {
  local sandbox ending expected rc content logger_pid
  sandbox="$(mktemp -d "${TMPDIR:-/tmp}/regression-capture-exit.XXXXXX")"
  mkdir -p "$sandbox/tmp" "$sandbox/linklogs"
  cat > "$sandbox/runner.sh" <<'RUNNER'
#!/bin/zsh
set -euo pipefail
source "$1/lib/utils.sh"
functions[original_locked_write]="$functions[ml_locked_write]"
ml_locked_write() {
  if [[ -n "$2" ]]; then
    [[ "$CAPTURE_ENDING" != logger-failure ]] || return 1
    /bin/sleep 0.05
  fi
  original_locked_write "$@"
}
enable_log_capture "$2/run.log"
printf '%s' "$ML_CAPTURE_PID" > "$2/logger-pid"
trap 'print -u2 SIGNAL_END; exit 143' TERM
for ((index=1; index<=500; index++)); do print "line-$index"; done
print -u2 FINAL_STDERR
case "$CAPTURE_ENDING" in
  normal) print FINAL_STDOUT ;;
  explicit) print FINAL_STDOUT; exit 42 ;;
  signal) kill -TERM $$ ;;
  logger-failure) print FINAL_STDOUT; exit 42 ;;
esac
RUNNER
  for ending expected in normal 0 explicit 42 signal 143 logger-failure 42; do
    rc=0
    CAPTURE_ENDING="$ending" TMPDIR="$sandbox/tmp" /bin/zsh "$sandbox/runner.sh" "$REPO_ROOT" "$sandbox" > "$sandbox/output" 2> "$sandbox/err" || rc=$?
    assert_eq "$rc" "$expected" "$ending: 日志记录保持业务退出码"
    content="$(<"$sandbox/output")"
    assert_contains "$content" FINAL_STDERR "$ending: 退出前排空终端错误输出"
    logger_pid="$(<"$sandbox/logger-pid")"
    (( logger_pid > 0 )) || fail "记录器必须有可等待的有效 PID"
    assert_not_contains "$(<"$sandbox/err")" 'not a child' "$ending: 无无效 PID 等待错误"
    if [[ "$ending" == logger-failure ]]; then
      assert_eq "$(grep -c '日志写入或轮转失败' "$sandbox/err")" 1 "运行中日志故障仅提示一次"
      assert_contains "$content" FINAL_STDOUT "日志失败后终端仍保留完整业务输出"
    else
      content="$(<"$sandbox/run.log")"
      if [[ "$ending" == signal ]]; then
        assert_contains "$content" SIGNAL_END "信号退出后日志包含最后的中断提示"
      else
        assert_contains "$content" FINAL_STDOUT "$ending: 返回调用方前最后日志已落盘"
      fi
    fi
    [[ -z "$(print -l -- "$sandbox/tmp"/macos-scripts-log.*(N))" ]] || fail "日志通道临时目录未清理"
    pass "$ending: 关闭并清理私有日志通道"
    rm -f "$sandbox/run.log" "$sandbox/run.log.lock"
  done
  ln -s "$sandbox/missing-target" "$sandbox/dangling.log"
  rc=0
  content="$(/bin/zsh -c 'source "$1/lib/utils.sh"; enable_log_capture "$2/dangling.log"' zsh "$REPO_ROOT" "$sandbox" 2>&1)" || rc=$?
  [[ "$rc" -ne 0 && ! -e "$sandbox/missing-target" ]] || fail "捕获入口不能创建失效符号链接的目标"
  pass "公共捕获入口先拒绝符号链接再打开日志"
  ln -s "$sandbox/bootstrap-target" "$sandbox/linklogs/bootstrap.log"
  local mode
  for mode in local pipe; do
    rc=0
    if [[ "$mode" == local ]]; then
      content="$(MACOS_SCRIPTS_LOG_DIR="$sandbox/linklogs" /bin/zsh "$REPO_ROOT/bootstrap/install.sh" --dry-run --yes 2>&1)" || rc=$?
    else
      content="$(cd "$sandbox"; MACOS_SCRIPTS_LOG_DIR="$sandbox/linklogs" /bin/zsh -s -- --dry-run --yes < "$REPO_ROOT/bootstrap/install.sh" 2>&1)" || rc=$?
    fi
    [[ "$rc" -ne 0 && ! -e "$sandbox/bootstrap-target" ]] || fail "$mode bootstrap 不能创建日志链接目标"
    assert_contains "$content" '日志路径不是普通文件' "$mode: bootstrap 在初始化前拒绝失效日志链接"
  done
  rm -rf "$sandbox"
}

test_queries_have_no_side_effects() {
  local sandbox spec entry phase result rc query_log query_config
  sandbox="$(mktemp -d "${TMPDIR:-/tmp}/regression-queries.XXXXXX")"
  mkdir -p "$sandbox/bin" "$sandbox/existing/logs" "$sandbox/existing/config/.bootstrap.lock"
  printf 'blocked\n' > "$sandbox/blocked"
  printf 'keep-log\n' > "$sandbox/existing/logs/bootstrap.log"
  printf 'keep-archive\n' > "$sandbox/existing/logs/bootstrap.log.9"
  printf 'keep-owner\n' > "$sandbox/existing/config/.bootstrap.lock/pid"
  local name
  for name in mkdir rm mv touch stat date sw_vers uname sysctl brew git gh curl ping xcode-select xcrun tee; do
    cat > "$sandbox/bin/$name" <<'SHIM'
#!/bin/zsh
printf '%s %s\n' "${0:t}" "$*" >> "$QUERY_CALLS"
exit 97
SHIM
  done
  chmod +x "$sandbox/bin/"*
  local HOME="$sandbox/home" PATH="$sandbox/bin:$PATH" QUERY_CALLS="$sandbox/calls"
  local MACOS_SCRIPTS_LOG_DIR MACOS_SCRIPTS_CONFIG_DIR
  # 非法日志策略若被初始化就会失败；纯查询应完全跳过。
  local MACOS_SCRIPTS_LOG_MAX_BYTES=invalid
  export HOME PATH QUERY_CALLS MACOS_SCRIPTS_LOG_DIR MACOS_SCRIPTS_CONFIG_DIR MACOS_SCRIPTS_LOG_MAX_BYTES
  local -a query_args query_cases=(
    'bin/macos-scripts|' 'bin/macos-scripts|help' 'bin/macos-scripts|--help' 'bin/macos-scripts|-h'
    'bin/macos-scripts|version' 'bin/macos-scripts|--version' 'bin/macos-scripts|-v'
    'bin/macos-scripts|setup' 'bin/macos-scripts|maintain' 'bin/macos-scripts|release'
    'bin/macos-scripts|help setup' 'bin/macos-scripts|help maintain installer create'
    'bin/macos-scripts|setup shell --help' 'bin/macos-scripts|setup packages --help'
    'bin/macos-scripts|setup brew configure --help' 'bin/macos-scripts|setup git --help'
    'bin/macos-scripts|setup github --help' 'bin/macos-scripts|maintain brew --help'
    'bin/macos-scripts|maintain installer list --help' 'bin/macos-scripts|maintain installer download --help'
    'bin/macos-scripts|maintain installer create --help' 'bin/macos-scripts|release verify --help'
    'bin/macos-scripts|release publish --help' 'bin/macos-scripts|lint --help'
    'bin/macos-scripts|lint check --help' 'bin/macos-scripts|lint fix --help'
    'bin/macos-scripts|lint --fix --help'
    'bootstrap/install.sh|--help' 'bootstrap/install.sh|-h' 'bootstrap/install.sh|help'
    'setup/homebrew-setup.sh|--help' 'setup/homebrew-setup.sh|help'
    'setup/macos-setup.sh|--help' 'setup/ohmyzsh-setup.sh|--help'
    'setup/git_forge_ssh_setup.sh|--help' 'maintain/formulaes_casks_updater.sh|--help'
    'maintain/github_release_publish.sh|--help' 'maintain/macos_sys_usb_maker.sh|--help'
    'maintain/macos_sys_usb_maker.sh|list --help' 'maintain/macos_sys_usb_maker.sh|download --help'
    'maintain/macos_sys_usb_maker.sh|create --help' 'maintain/macos_sys_usb_maker.sh|--verbose download --help'
    'lint/lint_shell.sh|--help'
  )
  for phase in fresh blocked existing; do
    case "$phase" in
      fresh) query_log="$sandbox/fresh/logs"; query_config="$sandbox/fresh/config" ;;
      blocked) query_log="$sandbox/blocked/logs"; query_config="$sandbox/blocked/config" ;;
      existing) query_log="$sandbox/existing/logs"; query_config="$sandbox/existing/config" ;;
    esac
    MACOS_SCRIPTS_LOG_DIR="$query_log"
    MACOS_SCRIPTS_CONFIG_DIR="$query_config"
    for spec in "${query_cases[@]}"; do
      entry="${spec%%|*}"
      query_args=( ${(z)${spec#*|}} )
      rc=0
      result="$(/bin/zsh "$REPO_ROOT/$entry" "${query_args[@]}" </dev/null 2>&1)" || rc=$?
      [[ "$rc" == 0 && -n "$result" ]] || fail "$phase/$spec 查询失败：$result"
    done
    pass "$phase: CLI 与独立脚本的帮助、版本查询均成功"
    rc=0
    result="$(cd "$sandbox"; /bin/zsh -s -- --help < "$REPO_ROOT/bootstrap/install.sh" 2>&1)" || rc=$?
    assert_eq "$rc" 0 "$phase: 独立管道帮助不依赖日志或系统检查"
    for entry in bootstrap/install.sh setup/homebrew-setup.sh setup/macos-setup.sh setup/ohmyzsh-setup.sh setup/git_forge_ssh_setup.sh maintain/formulaes_casks_updater.sh maintain/github_release_publish.sh maintain/macos_sys_usb_maker.sh bin/macos-scripts; do
      rc=0
      result="$(/bin/zsh "$REPO_ROOT/$entry" --bad-query-flag </dev/null 2>&1)" || rc=$?
      [[ "$rc" != 0 && "$result" == *未知* ]] || fail "$phase/$entry 无效参数应明确失败：$result"
    done
    rc=0
    result="$(/bin/zsh "$REPO_ROOT/bin/macos-scripts" version unexpected 2>&1)" || rc=$?
    [[ "$rc" != 0 && "$result" == *参数错误* ]] || fail "version 不应忽略多余参数"
    rc=0
    result="$(/bin/zsh "$REPO_ROOT/bin/macos-scripts" release publish --title help 2>&1)" || rc=$?
    [[ "$rc" != 0 && "$result" == *需要提供版本* ]] || fail "参数值 help 不应绕过 tag 校验"
    pass "$phase: 无效参数和版本查询多余参数仍返回非零"
    [[ ! -e "$QUERY_CALLS" ]] || fail "查询不应调用写入、系统或网络命令：$(<"$QUERY_CALLS")"
    pass "$phase: 不调用日志、目录、系统检查或网络命令"
  done
  [[ ! -e "$sandbox/fresh" && ! -e "$HOME" ]] || fail "查询不应创建日志、配置或用户目录"
  pass "帮助和版本查询不创建任何运行目录"
  assert_eq "$(<"$sandbox/existing/logs/bootstrap.log")" keep-log "查询不追加已有日志"
  assert_eq "$(<"$sandbox/existing/logs/bootstrap.log.9")" keep-archive "查询不轮转或清理归档"
  assert_eq "$(<"$sandbox/existing/config/.bootstrap.lock/pid")" keep-owner "查询不获取或释放已有锁"
  /bin/rm -rf "$sandbox"
}

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
    "$REPO_ROOT/bin" "$REPO_ROOT/bootstrap" \
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
  test_installer_stale_lock_takeover
  test_release_status_three_states
  test_unified_log_paths
  test_log_run_headers
  test_log_rotation
  test_xcode_no_check_compatibility
  test_first_line_helper
  test_macos_version_policy
  test_queries_have_no_side_effects
  test_log_capture_exit_and_links
  local help_result
  help_result="$(/bin/zsh -c '
    source "$1/bin/lib/cli_runtime.sh"
    for option in --title --notes-file --target --repo --domain --type --volume --installer-path --version; do
      has_help_flag "$option" help && exit 2
      has_help_flag "$option" --help && exit 3
      has_help_flag "$option" help --help || exit 4
    done
    printf okay
  ' zsh "$REPO_ROOT")"
  assert_eq "$help_result" okay "帮助检测跳过参数值但保留后续帮助开关"

  printf '\nRegression guard passed: %d\n' "$PASS_COUNT"
}

main "$@"
