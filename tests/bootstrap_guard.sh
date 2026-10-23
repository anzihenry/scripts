#!/bin/zsh
# filepath: tests/bootstrap_guard.sh
# 对本地文件与独立管道入口执行同一状态矩阵，所有安装/网络命令均为桩。
set -euo pipefail
setopt no_bg_nice

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h}"
BOOTSTRAP="$REPO_ROOT/bootstrap/install.sh"
source "$SCRIPT_DIR/e2e/e2e_lib.sh"
e2e_begin bootstrap-guard

# 将固定安装位置映射到沙箱，避免候选探测命中开发机真实 Homebrew。
FIXTURE_ROOT="$E2E_TMP_ROOT/repo"
mkdir -p "$FIXTURE_ROOT/bootstrap"
ln -s "$REPO_ROOT/lib" "$FIXTURE_ROOT/lib"
ln -s "$REPO_ROOT/setup" "$FIXTURE_ROOT/setup"
ln -s "$REPO_ROOT/VERSION" "$FIXTURE_ROOT/VERSION"
sed -e "s|/opt/homebrew/bin/brew|$E2E_TMP_ROOT/default-arm/bin/brew|g" \
    -e "s|/usr/local/bin/brew|$E2E_TMP_ROOT/default-intel/bin/brew|g" \
    "$BOOTSTRAP" > "$FIXTURE_ROOT/bootstrap/install.sh"
BOOTSTRAP="$FIXTURE_ROOT/bootstrap/install.sh"

TEST_BIN="$E2E_TMP_ROOT/bin"
mkdir -p "$TEST_BIN"
# brew 与 CLI 桩确保成功路径也不安装真实软件、不访问网络。
for shim in _recorder.sh brew macos-scripts curl; do
  ln -s "$E2E_SHIMS_DIR/$shim" "$TEST_BIN/$shim"
done
cat > "$TEST_BIN/uname" <<'SHIM'
#!/bin/zsh
[[ "${1:-}" == -m ]] || exit 127
[[ "${BOOTSTRAP_TEST_ARCH:-arm64}" != failed ]] || exit 1
printf '%s\n' "${BOOTSTRAP_TEST_ARCH-arm64}"
SHIM
cat > "$TEST_BIN/sysctl" <<'SHIM'
#!/bin/zsh
printf 'sysctl %s\n' "$*" >> "$E2E_TRANSCRIPT"
[[ "$*" == '-in sysctl.proc_translated' ]] || exit 127
case "${BOOTSTRAP_TEST_TRANSLATED:-native}" in
  native) printf '0\n' ;;
  translated) printf '1\n' ;;
  missing) exit 0 ;;
  failed) exit 1 ;;
  malformed) printf 'unknown\n' ;;
esac
SHIM
chmod +x "$TEST_BIN/uname" "$TEST_BIN/sysctl"
cat > "$TEST_BIN/xcode-select" <<'SHIM'
#!/bin/zsh
set -euo pipefail
source "${0:A:h}/_recorder.sh"
record_invocation "$@"
if [[ "${1:-}" == -p && -n "${BOOTSTRAP_TEST_SIGNAL:-}" ]]; then
  kill -s "$BOOTSTRAP_TEST_SIGNAL" "$PPID"
  exit 1
fi
if [[ "${1:-}" == -p && "${BOOTSTRAP_TEST_HOLD:-false}" == true ]]; then
  : > "$E2E_TMP_ROOT/bootstrap-hold-ready"
  for ((index = 0; index < 500; index++)); do
    [[ ! -f "$E2E_TMP_ROOT/bootstrap-hold-release" ]] || break
    /bin/sleep 0.02
  done
fi
case "${1:-}" in
  -p)
    if [[ "$BOOTSTRAP_TEST_CLT_SCENARIO" == ready || "$BOOTSTRAP_TEST_CLT_SCENARIO" == broken-existing || -f "$E2E_TMP_ROOT/clt-ready" ]]; then
      printf '/Library/Developer/CommandLineTools\n'
      exit 0
    fi
    exit 1
    ;;
  --install)
    [[ "$BOOTSTRAP_TEST_CLT_SCENARIO" != launch-failure ]] || exit 1
    : > "$E2E_TMP_ROOT/clt-started"
    ;;
  *) exit 127 ;;
esac
SHIM
cat > "$TEST_BIN/xcrun" <<'SHIM'
#!/bin/zsh
set -euo pipefail
source "${0:A:h}/_recorder.sh"
record_invocation "$@"
[[ "${1:-}" == --find && "${2:-}" == clang ]] || exit 127
case "$BOOTSTRAP_TEST_CLT_SCENARIO" in
  broken-existing|install-compiler-timeout) exit 1 ;;
  install-delayed) [[ -f "$E2E_TMP_ROOT/compiler-ready" ]] || exit 1 ;;
esac
printf '/Library/Developer/CommandLineTools/usr/bin/clang\n'
SHIM
cat > "$TEST_BIN/sleep" <<'SHIM'
#!/bin/zsh
set -euo pipefail
source "${0:A:h}/_recorder.sh"
record_invocation "$@"
# 不实际等待：成功用例在第一次轮询后就绪，超时用例始终未就绪。
if [[ "$BOOTSTRAP_TEST_CLT_SCENARIO" == install-success && -f "$E2E_TMP_ROOT/clt-started" ]]; then
  : > "$E2E_TMP_ROOT/clt-ready"
fi
if [[ "$BOOTSTRAP_TEST_CLT_SCENARIO" == install-delayed ]]; then
  if [[ -f "$E2E_TMP_ROOT/clt-ready" ]]; then : > "$E2E_TMP_ROOT/compiler-ready"; fi
  : > "$E2E_TMP_ROOT/clt-ready"
elif [[ "$BOOTSTRAP_TEST_CLT_SCENARIO" == install-compiler-timeout ]]; then
  : > "$E2E_TMP_ROOT/clt-ready"
fi
exit 0
SHIM
chmod +x "$TEST_BIN/xcode-select" "$TEST_BIN/xcrun" "$TEST_BIN/sleep"
export PATH="$TEST_BIN:$PATH"

# Zsh 自带 PTY 模块模拟真实控制终端，不依赖额外安装工具。
zmodload zsh/zpty
export BOOTSTRAP_TEST_SCRIPT="$BOOTSTRAP"
CONFIRM_RUNNER="$E2E_TMP_ROOT/confirm-runner.sh"
cat > "$CONFIRM_RUNNER" <<'RUNNER'
#!/bin/zsh
if [[ "$1" == pipe ]]; then
  /bin/cat "$BOOTSTRAP_TEST_SCRIPT" | /bin/zsh -s -- --skip-configure
else
  /bin/zsh "$BOOTSTRAP_TEST_SCRIPT" --skip-configure </dev/null
fi
result=$?
printf '\nBOOTSTRAP_CONFIRM_EXIT=%s\n' "$result"
RUNNER

run_confirm_mode() {
  local mode="$1" answer="$2"
  local chunk="" index sent=false
  export BOOTSTRAP_TEST_CLT_SCENARIO=ready
  : > "$E2E_TRANSCRIPT"
  E2E_RUN_OUTPUT=""
  E2E_RUN_STATUS=124
  zpty -b bootstrap_confirm /bin/zsh "${(q)CONFIRM_RUNNER}" "$mode"
  for ((index = 0; index < 400; index++)); do
    if zpty -r bootstrap_confirm chunk; then
      E2E_RUN_OUTPUT+="${chunk//$'\r'/}"
    fi
    if [[ "$sent" == false && "$E2E_RUN_OUTPUT" == *'是否继续 (y/N): '* ]]; then
      if [[ "$answer" == EOF ]]; then
        zpty -w -n bootstrap_confirm $'\x04'
      else
        zpty -w -n bootstrap_confirm "$answer"$'\n'
      fi
      sent=true
    fi
    if [[ "$E2E_RUN_OUTPUT" == *BOOTSTRAP_CONFIRM_EXIT=[0-9]*$'\n'* ]]; then
      E2E_RUN_STATUS="${${E2E_RUN_OUTPUT##*BOOTSTRAP_CONFIRM_EXIT=}%%$'\n'*}"
      break
    fi
    /bin/sleep 0.05
  done
  zpty -d bootstrap_confirm
}

run_mode() {
  local mode="$1" scenario="$2"
  shift 2
  export BOOTSTRAP_TEST_CLT_SCENARIO="$scenario"
  rm -f "$E2E_TMP_ROOT/clt-ready" "$E2E_TMP_ROOT/clt-started" "$E2E_TMP_ROOT/compiler-ready"
  : > "$E2E_TRANSCRIPT"
  if [[ "$mode" == local ]]; then
    e2e_run "$mode/$scenario" /bin/zsh "$BOOTSTRAP" "$@"
  else
    # 此目录没有仓库文件，保证执行的是独立 fallback。
    e2e_run "$mode/$scenario" /bin/zsh -s -- "$@" < "$BOOTSTRAP"
  fi
}

# 管道模式从无仓库文件的目录执行；HOME、日志与状态均在临时沙箱。
cd "$E2E_TMP_ROOT"
# 不运行 sudo、不更改实际 UID；仅在临时副本中将真实 EUID 判断固定为 root。
# 其余启动顺序和代码保持不变，验证两种进程入口在任何写入前退出。
ROOT_BOOTSTRAP="$E2E_TMP_ROOT/root-fixture.sh"
[[ "$(grep -c '^if (( EUID == 0 )); then$' "$BOOTSTRAP")" == 1 ]] || { e2e_fail "root 护栏必须使用有效 UID"; exit 1; }
sed 's/^if (( EUID == 0 )); then$/if (( 0 == 0 )); then/' "$BOOTSTRAP" > "$ROOT_BOOTSTRAP"
ROOT_CASE="$E2E_TMP_ROOT/root-case"
mkdir -p "$ROOT_CASE"
run_root_mode() {
  local mode="$1" log_dir="$2"
  shift 2
  : > "$E2E_TRANSCRIPT"
  if [[ "$mode" == local ]]; then
    e2e_run "root/$mode" env HOME="$ROOT_CASE/home" MACOS_SCRIPTS_LOG_DIR="$log_dir" MACOS_SCRIPTS_CONFIG_DIR="$ROOT_CASE/config" /bin/zsh "$ROOT_BOOTSTRAP" "$@"
  else
    e2e_run "root/$mode" env HOME="$ROOT_CASE/home" MACOS_SCRIPTS_LOG_DIR="$log_dir" MACOS_SCRIPTS_CONFIG_DIR="$ROOT_CASE/config" /bin/zsh -s -- "$@" < "$ROOT_BOOTSTRAP"
  fi
}
for mode in local pipe; do
  for execution in default actual dry-run; do
    root_args=()
    case "$execution" in
      actual) root_args=(--yes --skip-configure) ;;
      dry-run) root_args=(--dry-run) ;;
    esac
    run_root_mode "$mode" "$ROOT_CASE/logs" "${root_args[@]}"
    e2e_assert_eq "$E2E_RUN_STATUS" 1 "$mode/root/$execution: 拒绝 root 执行"
    e2e_assert_contains "$E2E_RUN_OUTPUT" '去掉 sudo' "$mode/root/$execution: 提示普通用户重试"
    e2e_assert_not_contains "$E2E_RUN_OUTPUT" '日志文件位置:' "$mode/root/$execution: 不伪报未创建的日志"
    [[ ! -e "$ROOT_CASE/home" && ! -e "$ROOT_CASE/logs" && ! -e "$ROOT_CASE/config" ]] && e2e_pass "$mode/root/$execution: 不创建日志、配置或锁" || e2e_fail "$mode/root/$execution: 提前退出不应写入目录"
    [[ ! -s "$E2E_TRANSCRIPT" ]] && e2e_pass "$mode/root/$execution: 不调用外部安装或检查命令" || e2e_fail "$mode/root/$execution: 不应进入系统检查或安装"
  done
  for help_option in --help -h help; do
    run_root_mode "$mode" "$ROOT_CASE/logs" --dry-run "$help_option"
    e2e_assert_eq "$E2E_RUN_STATUS" 0 "$mode/root/$help_option: 帮助可用"
    e2e_assert_contains "$E2E_RUN_OUTPUT" '用法:' "$mode/root/$help_option: 输出完整帮助"
    [[ ! -e "$ROOT_CASE/home" && ! -e "$ROOT_CASE/logs" && ! -e "$ROOT_CASE/config" ]] && e2e_pass "$mode/root/$help_option: 帮助不创建目录" || e2e_fail "$mode/root/$help_option: 帮助不应写入"
  done
  printf 'blocked\n' > "$ROOT_CASE/blocked"
  run_root_mode "$mode" "$ROOT_CASE/blocked/logs" --dry-run
  e2e_assert_contains "$E2E_RUN_OUTPUT" '不能以 root 身份运行' "$mode/root: 拒绝发生在日志可写性检查前"
  e2e_assert_not_contains "$E2E_RUN_OUTPUT" '日志目录或文件不可写' "$mode/root: 不初始化日志"
done
mkdir -p "$ROOT_CASE/existing-logs" "$ROOT_CASE/config/.bootstrap.lock"
printf 'existing-log\n' > "$ROOT_CASE/existing-logs/bootstrap.log"
printf 'existing-archive\n' > "$ROOT_CASE/existing-logs/bootstrap.log.1"
printf 'existing-owner\n' > "$ROOT_CASE/config/.bootstrap.lock/pid"
for mode in local pipe; do
  for root_option in --yes --help; do
    run_root_mode "$mode" "$ROOT_CASE/existing-logs" "$root_option"
    e2e_assert_eq "$(<"$ROOT_CASE/existing-logs/bootstrap.log")" existing-log "$mode/root/$root_option: 不修改已有日志"
    e2e_assert_eq "$(<"$ROOT_CASE/existing-logs/bootstrap.log.1")" existing-archive "$mode/root/$root_option: 不轮转或清理归档"
    e2e_assert_eq "$(<"$ROOT_CASE/config/.bootstrap.lock/pid")" existing-owner "$mode/root/$root_option: 不释放已有运行锁"
  done
done
for mode in local pipe; do
  for arch_case in arm64 x86_64 rosetta ppc64 empty failed; do
    export BOOTSTRAP_TEST_ARCH="$arch_case" BOOTSTRAP_TEST_TRANSLATED=native
    case "$arch_case" in
      rosetta) export BOOTSTRAP_TEST_ARCH=x86_64 BOOTSTRAP_TEST_TRANSLATED=translated ;;
      empty) export BOOTSTRAP_TEST_ARCH='' ;;
    esac
    for execution in actual dry-run; do
      arch_args=(--yes --skip-configure)
      [[ "$execution" != dry-run ]] || arch_args+=(--dry-run)
      run_mode "$mode" ready "${arch_args[@]}"
      case "$arch_case" in
        arm64|x86_64|rosetta)
          e2e_assert_eq "$E2E_RUN_STATUS" 0 "$mode/$arch_case/$execution: 支持的架构继续"
          e2e_assert_contains "$E2E_RUN_OUTPUT" "运行架构: $BOOTSTRAP_TEST_ARCH" "$mode/$arch_case/$execution: 显示运行架构"
          if [[ "$arch_case" == rosetta ]]; then
            e2e_assert_contains "$E2E_RUN_OUTPUT" '检测到 Rosetta' "$mode/$execution: Rosetta 提示原生终端"
            e2e_assert_contains "$E2E_RUN_OUTPUT" '不自动迁移或重装' "$mode/$execution: 保留已有 Homebrew"
            if [[ "$execution" == actual ]]; then
              e2e_assert_transcript_contains 'brew tap' "$mode: Rosetta 仍使用已安装 Homebrew"
              e2e_assert_transcript_not_contains 'curl ' "$mode: Rosetta 不重装已可用 Homebrew"
            fi
          else
            e2e_assert_not_contains "$E2E_RUN_OUTPUT" '检测到 Rosetta' "$mode/$arch_case/$execution: 原生环境不误报"
          fi
          [[ "$arch_case" != arm64 ]] || e2e_assert_transcript_not_contains 'sysctl ' "$mode/$execution: arm64 不查询 Rosetta"
          ;;
        *)
          [[ "$E2E_RUN_STATUS" -ne 0 ]] && e2e_pass "$mode/$arch_case/$execution: 无效架构中止" || e2e_fail "$mode/$arch_case/$execution: 无效架构中止"
          e2e_assert_contains "$E2E_RUN_OUTPUT" '架构' "$mode/$arch_case/$execution: 明确架构诊断"
          e2e_assert_transcript_not_contains 'xcode-select ' "$mode/$arch_case/$execution: 不进入 CLT"
          e2e_assert_transcript_not_contains 'brew ' "$mode/$arch_case/$execution: 不进入 Homebrew"
          e2e_assert_transcript_not_contains 'curl ' "$mode/$arch_case/$execution: 不下载"
          [[ ! -d "$MACOS_SCRIPTS_CONFIG_DIR/.bootstrap.lock" ]] && e2e_pass "$mode/$arch_case/$execution: 预检失败不占运行锁" || e2e_fail "$mode/$arch_case/$execution: 预检失败不占运行锁"
          ;;
      esac
    done
  done
  export BOOTSTRAP_TEST_ARCH=x86_64
  for translated_case in missing failed malformed; do
    export BOOTSTRAP_TEST_TRANSLATED="$translated_case"
    run_mode "$mode" ready --dry-run
    e2e_assert_eq "$E2E_RUN_STATUS" 0 "$mode/$translated_case: Rosetta 状态不明不阻断 Intel"
    e2e_assert_not_contains "$E2E_RUN_OUTPUT" '检测到 Rosetta' "$mode/$translated_case: 不误判转译状态"
  done
  export BOOTSTRAP_TEST_ARCH=ppc64
  run_mode "$mode" ready --help
  e2e_assert_eq "$E2E_RUN_STATUS" 0 "$mode: 不支持的架构仍可查看帮助"
  e2e_assert_not_contains "$E2E_RUN_OUTPUT" '不支持的运行架构' "$mode: 帮助不执行架构检查"
done
unset BOOTSTRAP_TEST_ARCH BOOTSTRAP_TEST_TRANSLATED
for mode in local pipe; do
  for answer in y Y '' n yes EOF; do
    run_confirm_mode "$mode" "$answer"
    e2e_assert_eq "$E2E_RUN_STATUS" 0 "$mode/${answer:-回车}: 确认正常结束"
    if [[ "$answer" == y || "$answer" == Y ]]; then
      e2e_assert_transcript_contains 'brew tap' "$mode/$answer: 从控制终端确认后继续"
    else
      e2e_assert_contains "$E2E_RUN_OUTPUT" '已取消 bootstrap' "$mode/${answer:-回车}: 默认取消"
      e2e_assert_not_contains "$E2E_RUN_OUTPUT" 'bootstrap 失败，阶段:' "$mode/${answer:-回车}: 取消不报告失败"
      e2e_assert_not_contains "$E2E_RUN_OUTPUT" 'bootstrap 已中断' "$mode/${answer:-回车}: 取消不报告中断"
      e2e_assert_transcript_not_contains 'xcode-select ' "$mode/${answer:-回车}: 取消后不开始安装"
    fi
  done

  # 无控制终端的 CI 中，stdin 即使有 y 也不能替代终端授权。
  if ! (: </dev/tty) 2>/dev/null; then
    run_mode "$mode" ready --skip-configure <<< 'y'
    e2e_assert_eq "$E2E_RUN_STATUS" 2 "$mode: 无终端时返回非零"
    e2e_assert_contains "$E2E_RUN_OUTPUT" '请添加 --yes' "$mode: 无终端给出明确提示"
    e2e_assert_contains "$E2E_RUN_OUTPUT" 'bootstrap 失败，阶段: 安装确认' "$mode: 无终端报告确认阶段失败"
    e2e_assert_transcript_not_contains 'xcode-select ' "$mode: 无终端不开始安装"
  fi

  run_mode "$mode" ready --yes --skip-configure
  e2e_assert_eq "$E2E_RUN_STATUS" 0 "$mode: 已安装时成功"
  e2e_assert_contains "$E2E_RUN_OUTPUT" 'Xcode 命令行工具已就绪' "$mode: 识别已安装 CLT"
  e2e_assert_contains "$E2E_RUN_OUTPUT" '===== 运行开始 =====' "$mode: 输出运行分隔"
  e2e_assert_contains "$E2E_RUN_OUTPUT" '脚本: install.sh' "$mode: 独立入口和本地入口脚本名一致"
  e2e_assert_contains "$E2E_RUN_OUTPUT" '模式: 实际执行' "$mode: 实际执行模式正确"
  e2e_assert_eq "$(grep -c '^===== 运行开始 =====$' <<< "$E2E_RUN_OUTPUT")" 1 "$mode: 每次运行只输出一个分隔头"
  e2e_assert_transcript_not_contains 'xcode-select --install' "$mode: 不重复安装 CLT"
  e2e_assert_transcript_not_contains 'sleep ' "$mode: 已就绪不等待"
  e2e_assert_transcript_contains 'xcrun --find clang' "$mode: 已有 CLT 也验证 clang 定位"
  e2e_assert_transcript_contains 'brew install anzihenry/scripts/macos-scripts' "$mode: 继续 tap 安装流程"

  export E2E_BREW_INSTALLED_FORMULA=macos-scripts
  run_mode "$mode" ready --yes
  e2e_assert_eq "$E2E_RUN_STATUS" 0 "$mode: 已安装 CLI 时成功"
  e2e_assert_transcript_not_contains 'brew install ' "$mode: 已安装 CLI 不重复安装"
  e2e_assert_transcript_not_contains 'brew upgrade ' "$mode: 已安装 CLI 不自动升级"
  e2e_assert_transcript_contains 'macos-scripts setup brew configure' "$mode: 已安装 CLI 继续配置"
  unset E2E_BREW_INSTALLED_FORMULA

  export E2E_CLI_VERSION_STATUS=42
  run_mode "$mode" ready --yes
  e2e_assert_eq "$E2E_RUN_STATUS" 1 "$mode: CLI 版本检查失败中止"
  e2e_assert_contains "$E2E_RUN_OUTPUT" 'macos-scripts --version 执行失败' "$mode: CLI 不可用给出明确诊断"
  e2e_assert_transcript_not_contains 'macos-scripts setup brew configure' "$mode: CLI 不可用不执行配置"
  unset E2E_CLI_VERSION_STATUS

  run_mode "$mode" broken-existing --yes
  e2e_assert_eq "$E2E_RUN_STATUS" 1 "$mode: 已有路径但 clang 不可用时中止"
  e2e_assert_contains "$E2E_RUN_OUTPUT" '开发工具路径已存在，但无法定位 clang' "$mode: 损坏工具链给出修复提示"
  e2e_assert_transcript_not_contains 'xcode-select --install' "$mode: 损坏工具链不重复启动安装"
  e2e_assert_transcript_not_contains 'brew ' "$mode: 损坏工具链阻止后续安装"
  run_mode "$mode" broken-existing --dry-run
  e2e_assert_eq "$E2E_RUN_STATUS" 1 "$mode: dry-run 仍检查已有工具链"
  e2e_assert_transcript_not_contains 'xcode-select --install' "$mode: 损坏工具链预演不触发安装"
  e2e_assert_transcript_not_contains 'sleep ' "$mode: 损坏工具链预演不等待"

  run_mode "$mode" install-delayed --yes --skip-configure
  e2e_assert_eq "$E2E_RUN_STATUS" 0 "$mode: 路径先就绪而 clang 稍后就绪时成功"
  e2e_assert_eq "$(grep -c '^sleep 5$' "$E2E_TRANSCRIPT")" 2 "$mode: 必须等 clang 就绪才继续"
  e2e_assert_transcript_order "$mode: 安装后验证 clang 再进入 Homebrew" 'xcode-select --install' 'xcrun --find clang' 'brew tap'

  run_mode "$mode" install-compiler-timeout --yes --skip-configure
  e2e_assert_eq "$E2E_RUN_STATUS" 1 "$mode: 安装后仅有路径而无 clang 时超时"
  e2e_assert_contains "$E2E_RUN_OUTPUT" 'xcrun --find clang' "$mode: 超时提示包含工具定位检查"
  e2e_assert_transcript_not_contains 'brew ' "$mode: 编译器未就绪不进入后续安装"

  run_mode "$mode" install-success --yes --skip-configure
  e2e_assert_eq "$E2E_RUN_STATUS" 0 "$mode: 安装完成后成功"
  e2e_assert_contains "$E2E_RUN_OUTPUT" 'Xcode 命令行工具已安装' "$mode: 报告 CLT 安装完成"
  e2e_assert_contains "$E2E_RUN_OUTPUT" '--yes 不会自动操作该窗口' "$mode: 明确系统窗口需手动完成"
  e2e_assert_transcript_contains 'sleep 5' "$mode: 等待安装完成"
  e2e_assert_transcript_order "$mode: CLT 完成后才进入 Homebrew" 'xcode-select --install' 'sleep 5' 'brew tap'

  run_mode "$mode" launch-failure --yes --skip-configure
  e2e_assert_eq "$E2E_RUN_STATUS" 1 "$mode: 启动安装失败返回非零"
  e2e_assert_contains "$E2E_RUN_OUTPUT" '请手动执行 xcode-select --install' "$mode: 给出恢复方式"
  e2e_assert_contains "$E2E_RUN_OUTPUT" 'bootstrap 失败，阶段: 检查/安装 Xcode 命令行工具' "$mode: CLT 失败摘要指出阶段"
  e2e_assert_transcript_not_contains 'brew ' "$mode: 安装启动失败阻止 Homebrew 流程"
  e2e_assert_transcript_not_contains 'sleep ' "$mode: 启动失败不进入等待"

  run_mode "$mode" timeout --yes --skip-configure
  e2e_assert_eq "$E2E_RUN_STATUS" 1 "$mode: 等待超时返回非零"
  e2e_assert_contains "$E2E_RUN_OUTPUT" '安装超时（600 秒）' "$mode: 超时诊断与等待上限一致"
  e2e_assert_eq "$(grep -c '^sleep 5$' "$E2E_TRANSCRIPT")" 120 "$mode: 等待次数有界"
  e2e_assert_transcript_not_contains 'brew ' "$mode: 超时阻止 Homebrew 流程"

  # 故意不传 --yes，验证 dry-run 在管道模式也无需读取 stdin。
  run_mode "$mode" timeout --dry-run
  e2e_assert_eq "$E2E_RUN_STATUS" 0 "$mode: 缺失 CLT 时仍可完整预演"
  e2e_assert_contains "$E2E_RUN_OUTPUT" '[dry-run] 将执行 xcode-select --install' "$mode: 预览 CLT 安装"
  e2e_assert_contains "$E2E_RUN_OUTPUT" 'Bootstrap dry-run 完成' "$mode: 预演继续到结束"
  e2e_assert_contains "$E2E_RUN_OUTPUT" '模式: dry-run' "$mode: 预演运行头正确标记模式"
  e2e_assert_transcript_not_contains 'xcode-select --install' "$mode: dry-run 不触发安装窗口"
  e2e_assert_transcript_not_contains 'xcrun --find clang' "$mode: 缺失 CLT 时预演不调用工具定位"
  e2e_assert_transcript_not_contains 'sleep ' "$mode: dry-run 不等待"
  e2e_assert_transcript_not_contains 'brew tap' "$mode: dry-run 不添加 tap"
  e2e_assert_transcript_not_contains 'brew install' "$mode: dry-run 不安装 CLI"

  run_mode "$mode" ready --help
  e2e_assert_eq "$E2E_RUN_STATUS" 0 "$mode: 帮助入口成功"
  e2e_assert_contains "$E2E_RUN_OUTPUT" '--dry-run' "$mode: 帮助列出预演选项"
  e2e_assert_transcript_not_contains 'xcode-select ' "$mode: 帮助不检查 CLT"

  run_mode "$mode" ready --bogus-flag
  e2e_assert_eq "$E2E_RUN_STATUS" 1 "$mode: 未知参数返回非零"
  e2e_assert_contains "$E2E_RUN_OUTPUT" '未知参数' "$mode: 未知参数给出诊断"
  e2e_assert_not_contains "$E2E_RUN_OUTPUT" '日志文件位置:' "$mode: 参数错误不初始化或伪报日志"
done

BOOTSTRAP_LOCK="$E2E_CONFIG_DIR/.bootstrap.lock"
for mode in local pipe; do
  run_mode "$mode" ready --yes --skip-configure
  [[ ! -e "$BOOTSTRAP_LOCK" ]] && e2e_pass "$mode: 正常完成释放运行锁" || e2e_fail "$mode: 正常完成锁残留"
  run_mode "$mode" launch-failure --yes
  e2e_assert_eq "$E2E_RUN_STATUS" 1 "$mode: 安装失败保持非零状态"
  [[ ! -e "$BOOTSTRAP_LOCK" ]] && e2e_pass "$mode: 安装失败释放运行锁" || e2e_fail "$mode: 失败锁残留"

  for signal_name expected_status in INT 130 TERM 143 HUP 129; do
    export BOOTSTRAP_TEST_SIGNAL="$signal_name"
    run_mode "$mode" ready --yes
    e2e_assert_eq "$E2E_RUN_STATUS" "$expected_status" "$mode/$signal_name: 保留中断退出码"
    e2e_assert_contains "$E2E_RUN_OUTPUT" "bootstrap 已中断（SIG${signal_name}），阶段: 检查/安装 Xcode 命令行工具" "$mode/$signal_name: 明确提示中断及阶段"
    e2e_assert_eq "$(grep -c 'bootstrap 已中断' <<< "$E2E_RUN_OUTPUT")" 1 "$mode/$signal_name: 中断摘要只输出一次"
    e2e_assert_not_contains "$E2E_RUN_OUTPUT" 'bootstrap 失败，阶段:' "$mode/$signal_name: 中断不混报普通失败"
    e2e_assert_contains "$E2E_RUN_OUTPUT" "日志文件位置: $E2E_LOG_DIR/bootstrap.log" "$mode/$signal_name: 中断提示日志位置"
    e2e_assert_contains "$E2E_RUN_OUTPUT" '恢复建议:' "$mode/$signal_name: 中断提供恢复建议"
    [[ ! -e "$BOOTSTRAP_LOCK" ]] && e2e_pass "$mode/$signal_name: 中断释放运行锁" || e2e_fail "$mode/$signal_name: 中断锁残留"
  done
  unset BOOTSTRAP_TEST_SIGNAL

  # 模拟强制终止留下的锁：不自动删除或抢占。
  mkdir "$BOOTSTRAP_LOCK"
  printf 'stale-test-owner\n' > "$BOOTSTRAP_LOCK/pid"
  run_mode "$mode" ready --yes
  e2e_assert_eq "$E2E_RUN_STATUS" 1 "$mode: 已有运行锁时拒绝安装"
  e2e_assert_contains "$E2E_RUN_OUTPUT" '确认原进程已结束' "$mode: 残留锁提示先确认再清理"
  e2e_assert_contains "$E2E_RUN_OUTPUT" "$BOOTSTRAP_LOCK/pid" "$mode: 提示锁和 PID 位置"
  e2e_assert_contains "$E2E_RUN_OUTPUT" 'bootstrap 失败，阶段: 获取运行锁' "$mode: 锁冲突摘要指出阶段"
  e2e_assert_eq "$(<"$BOOTSTRAP_LOCK/pid")" stale-test-owner "$mode: 不修改其他进程的锁"
  e2e_assert_transcript_not_contains 'xcode-select ' "$mode: 被锁阻止时不开始安装"
  run_mode "$mode" ready --help
  e2e_assert_eq "$E2E_RUN_STATUS" 0 "$mode: 已有锁时帮助仍可用"
  run_mode "$mode" ready --dry-run
  e2e_assert_eq "$E2E_RUN_STATUS" 0 "$mode: 已有锁时仍可预演"
  e2e_assert_eq "$(<"$BOOTSTRAP_LOCK/pid")" stale-test-owner "$mode: 帮助和预演不改锁"
  rm "$BOOTSTRAP_LOCK/pid"
  rmdir "$BOOTSTRAP_LOCK"

  # 真实并发：首个沙箱进程在 CLT 检查中等待，第二个必须立即失败。
  rm -f "$E2E_TMP_ROOT/bootstrap-hold-ready" "$E2E_TMP_ROOT/bootstrap-hold-release"
  export BOOTSTRAP_TEST_CLT_SCENARIO=ready
  if [[ "$mode" == local ]]; then
    BOOTSTRAP_TEST_HOLD=true /bin/zsh "$BOOTSTRAP" --yes --skip-configure > "$E2E_TMP_ROOT/first-bootstrap.log" 2>&1 &
  else
    BOOTSTRAP_TEST_HOLD=true /bin/zsh -s -- --yes --skip-configure < "$BOOTSTRAP" > "$E2E_TMP_ROOT/first-bootstrap.log" 2>&1 &
  fi
  first_pid=$!
  for ((index = 0; index < 200; index++)); do
    [[ ! -f "$E2E_TMP_ROOT/bootstrap-hold-ready" ]] || break
    /bin/sleep 0.025
  done
  e2e_assert_file "$E2E_TMP_ROOT/bootstrap-hold-ready" "$mode: 首个安装流程已持锁运行"
  e2e_assert_eq "$(<"$BOOTSTRAP_LOCK/pid")" "$first_pid" "$mode: 锁记录实际进程 PID"
  e2e_assert_eq "$(stat -f '%Lp' "$BOOTSTRAP_LOCK")" 700 "$mode: 运行锁仅当前用户可访问"
  run_mode "$mode" ready --yes --skip-configure
  e2e_assert_eq "$E2E_RUN_STATUS" 1 "$mode: 并发的第二个进程立即退出"
  e2e_assert_eq "$(<"$BOOTSTRAP_LOCK/pid")" "$first_pid" "$mode: 第二个进程未释放首个进程的锁"
  : > "$E2E_TMP_ROOT/bootstrap-hold-release"
  if wait "$first_pid"; then e2e_pass "$mode: 首个安装流程正常完成"; else e2e_fail "$mode: 首个安装流程失败"; fi
  [[ ! -e "$BOOTSTRAP_LOCK" ]] && e2e_pass "$mode: 并发验证后运行锁释放" || e2e_fail "$mode: 并发验证后锁残留"
done

# 多候选探测：所有入口与状态均在沙箱，后续 tap/install 也必须使用选中入口。
export BOOTSTRAP_TEST_SHIMS="$E2E_SHIMS_DIR"
mkdir -p "$E2E_TMP_ROOT/default-arm/bin" "$E2E_TMP_ROOT/default-intel/bin"
PROBE_SHIM="$E2E_TMP_ROOT/probe-brew.sh"
cat > "$PROBE_SHIM" <<'SHIM'
#!/bin/zsh
set -euo pipefail
case "$0" in
  */default-arm/*) probe_name=arm; probe_status="${BOOTSTRAP_TEST_ARM_STATUS:-0}" ;;
  */default-intel/*) probe_name=intel; probe_status="${BOOTSTRAP_TEST_INTEL_STATUS:-0}" ;;
  *) probe_name=path; probe_status="${BOOTSTRAP_TEST_PATH_STATUS:-0}" ;;
esac
printf 'probe-%s %s\n' "$probe_name" "$*" >> "$E2E_TRANSCRIPT"
if [[ "${1:-}" == --version ]]; then
  (( probe_status == 0 )) || exit "$probe_status"
elif [[ "${1:-}" == shellenv ]]; then
  # 保持失效 PATH 入口在前，验证实际操作使用解析出的绝对路径。
  exit 0
fi
exec /bin/zsh "$BOOTSTRAP_TEST_SHIMS/brew" "$@"
SHIM
chmod +x "$PROBE_SHIM"
rm "$TEST_BIN/brew"
cp "$PROBE_SHIM" "$TEST_BIN/brew"
cp "$PROBE_SHIM" "$E2E_TMP_ROOT/default-arm/bin/brew"
cp "$PROBE_SHIM" "$E2E_TMP_ROOT/default-intel/bin/brew"
for mode in local pipe; do
  export BOOTSTRAP_TEST_PATH_STATUS=0 BOOTSTRAP_TEST_ARM_STATUS=0 BOOTSTRAP_TEST_INTEL_STATUS=0
  run_mode "$mode" ready --yes --skip-configure
  e2e_assert_eq "$E2E_RUN_STATUS" 0 "$mode: 多个可用入口时成功"
  e2e_assert_transcript_contains 'probe-path tap' "$mode: PATH 可用时优先使用"
  e2e_assert_transcript_not_contains 'probe-arm ' "$mode: PATH 可用时不探测后续入口"

  export BOOTSTRAP_TEST_PATH_STATUS=1
  run_mode "$mode" ready --yes --skip-configure
  e2e_assert_eq "$E2E_RUN_STATUS" 0 "$mode: PATH 失效时改用 ARM 入口"
  e2e_assert_contains "$E2E_RUN_OUTPUT" "实际选用: $E2E_TMP_ROOT/default-arm/bin/brew" "$mode: 提示实际选用路径"
  e2e_assert_transcript_contains 'probe-arm tap' "$mode: ARM 入口执行 tap"
  e2e_assert_transcript_contains 'probe-arm install' "$mode: ARM 入口执行安装"
  e2e_assert_transcript_not_contains 'probe-path tap' "$mode: 不误用失效 PATH 入口"
  e2e_assert_transcript_not_contains 'curl ' "$mode: 有可用入口时不重装 Homebrew"

  export BOOTSTRAP_TEST_ARM_STATUS=1
  run_mode "$mode" ready --yes --skip-configure
  e2e_assert_eq "$E2E_RUN_STATUS" 0 "$mode: PATH 和 ARM 均失效时使用 Intel 入口"
  e2e_assert_contains "$E2E_RUN_OUTPUT" "实际选用: $E2E_TMP_ROOT/default-intel/bin/brew" "$mode: 提示 Intel 入口路径"
  e2e_assert_transcript_contains 'probe-intel tap' "$mode: Intel 入口执行 tap"
  e2e_assert_transcript_not_contains 'curl ' "$mode: Intel 可用时不重装 Homebrew"
done

# 单次探测去重：PATH 中的符号链接和固定位置指向同一文件时只执行一次。
RESOLVER_RUNNER="$E2E_TMP_ROOT/resolve-brew.sh"
printf '#!/bin/zsh\nwarning() { printf "%%s\\n" "$*" >&2; }\n' > "$RESOLVER_RUNNER"
awk '/^resolve_usable_homebrew_bin\(\)/ { active=1 } active { print } active && /^}/ { exit }' "$BOOTSTRAP" >> "$RESOLVER_RUNNER"
printf '\nresolve_usable_homebrew_bin\n' >> "$RESOLVER_RUNNER"
rm "$TEST_BIN/brew"
ln -s "$E2E_TMP_ROOT/default-arm/bin/brew" "$TEST_BIN/brew"
export BOOTSTRAP_TEST_PATH_STATUS=1 BOOTSTRAP_TEST_ARM_STATUS=1 BOOTSTRAP_TEST_INTEL_STATUS=1
: > "$E2E_TRANSCRIPT"
e2e_run_expect_failure "所有候选都不可用时探测失败" /bin/zsh "$RESOLVER_RUNNER"
e2e_assert_eq "$(grep -c '^probe-.* --version$' "$E2E_TRANSCRIPT")" 2 "符号链接重复候选只验证一次"
e2e_assert_eq "$E2E_RUN_OUTPUT" '' "探测失败不输出伪路径"

mkdir -p "$E2E_TMP_ROOT/relative bin"
cp "$PROBE_SHIM" "$E2E_TMP_ROOT/relative bin/brew"
export BOOTSTRAP_TEST_PATH_STATUS=0
: > "$E2E_TRANSCRIPT"
e2e_run_expect_success "支持 PATH 中带空格的相对目录" env PATH="relative bin:$PATH" /bin/zsh "$RESOLVER_RUNNER"
e2e_assert_eq "$E2E_RUN_OUTPUT" "$E2E_TMP_ROOT/relative bin/brew" "相对候选返回可执行的绝对路径"

rm "$E2E_TMP_ROOT/default-arm/bin/brew" "$E2E_TMP_ROOT/default-intel/bin/brew"
unset BOOTSTRAP_TEST_PATH_STATUS BOOTSTRAP_TEST_ARM_STATUS BOOTSTRAP_TEST_INTEL_STATUS

# 全新 Homebrew 场景：PATH 中的 brew 在安装标记出现前不可用。
rm -f "$TEST_BIN/brew" "$TEST_BIN/curl"
cat > "$TEST_BIN/brew" <<'SHIM'
#!/bin/zsh
set -euo pipefail
if [[ ! -f "$E2E_TMP_ROOT/brew-ready" ]]; then
  printf 'brew-unavailable %s\n' "$*" >> "$E2E_TRANSCRIPT"
  exit 1
fi
exec /bin/zsh "$BOOTSTRAP_TEST_ORIGINAL_SHIMS/brew" "$@"
SHIM
cat > "$TEST_BIN/curl" <<'SHIM'
#!/bin/zsh
set -euo pipefail
source "${0:A:h}/_recorder.sh"
record_invocation "$@"
case "${argv[-1]}" in
  *raw.githubusercontent.com/Homebrew/install/*) source_name=official ;;
  *mirrors.ustc.edu.cn/misc/brew-install.sh) source_name=ustc ;;
  *) exit 127 ;;
esac
if [[ "$BOOTSTRAP_TEST_INSTALL_SCENARIO" == both-download-timeout ]] ||
   [[ "$BOOTSTRAP_TEST_INSTALL_SCENARIO" == download-timeout && "$source_name" == official ]]; then
  printf ': > "$E2E_TMP_ROOT/partial-download-executed"\n'
  exit 28
fi
if [[ "$source_name" == official ]]; then
  case "$BOOTSTRAP_TEST_INSTALL_SCENARIO" in
    download-failure)
      # 部分响应不可执行，即便 curl 输出了非空内容。
      printf ': > "$E2E_TMP_ROOT/partial-download-executed"\n'
      exit 22
      ;;
    empty-download) printf '  \n'; exit 0 ;;
  esac
fi
printf 'source_name=%q\n' "$source_name"
cat <<'INSTALLER'
printf 'installer %s NONINTERACTIVE=%s INTERACTIVE=%s\n' "$source_name" "${NONINTERACTIVE-unset}" "${INTERACTIVE-unset}" >> "$E2E_TRANSCRIPT"
case "$BOOTSTRAP_TEST_INSTALL_SCENARIO/$source_name" in
  official-success/official|partial-success/official|fallback/ustc|download-failure/ustc|empty-download/ustc|download-timeout/ustc)
    : > "$E2E_TMP_ROOT/brew-ready"
    ;;
esac
case "$BOOTSTRAP_TEST_INSTALL_SCENARIO/$source_name" in
  partial-success/official|fallback/official|both-fail/official) exit 7 ;;
  both-fail/ustc) exit 8 ;;
esac
exit 0
INSTALLER
SHIM
chmod +x "$TEST_BIN/brew" "$TEST_BIN/curl"
export BOOTSTRAP_TEST_ORIGINAL_SHIMS="$E2E_SHIMS_DIR"
# --yes 必须覆盖交互环境冲突；只对子进程生效。
export INTERACTIVE=1
unset NONINTERACTIVE
for mode in local pipe; do
  for scenario in official-success partial-success fallback download-failure empty-download download-timeout both-download-timeout both-fail false-success; do
    export BOOTSTRAP_TEST_INSTALL_SCENARIO="$scenario"
    rm -f "$E2E_TMP_ROOT/brew-ready" "$E2E_TMP_ROOT/partial-download-executed"
    run_mode "$mode" ready --yes --skip-configure
    e2e_assert_transcript_contains 'curl -fsSL --connect-timeout 10 --max-time 120 https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh' "$mode/$scenario: 官方下载带超时限制"
    if [[ "$scenario" == both-fail || "$scenario" == false-success || "$scenario" == both-download-timeout ]]; then
      e2e_assert_eq "$E2E_RUN_STATUS" 1 "$mode/$scenario: 无可用 brew 时中止"
      e2e_assert_transcript_not_contains 'brew tap' "$mode/$scenario: 不进入 tap 安装"
      case "$scenario" in
        both-fail) expected_stage='执行 Homebrew USTC 安装脚本' ;;
        false-success) expected_stage='验证 Homebrew 可用性' ;;
        both-download-timeout) expected_stage='下载 Homebrew USTC 安装脚本' ;;
      esac
      e2e_assert_contains "$E2E_RUN_OUTPUT" "bootstrap 失败，阶段: $expected_stage" "$mode/$scenario: 指出最终失败阶段"
    else
      e2e_assert_eq "$E2E_RUN_STATUS" 0 "$mode/$scenario: 安装成功继续"
      e2e_assert_transcript_contains 'brew tap' "$mode/$scenario: 验证 brew 后继续"
      e2e_assert_not_contains "$E2E_RUN_OUTPUT" 'bootstrap 失败，阶段:' "$mode/$scenario: 成功恢复后不输出失败摘要"
    fi
    if [[ "$scenario" == official-success || "$scenario" == partial-success ]]; then
      e2e_assert_transcript_not_contains 'mirrors.ustc.edu.cn/misc/brew-install.sh' "$mode/$scenario: brew 可用时不重复安装"
    else
      e2e_assert_transcript_contains 'mirrors.ustc.edu.cn/misc/brew-install.sh' "$mode/$scenario: 自动尝试 USTC"
      e2e_assert_transcript_contains 'curl -fsSL --connect-timeout 10 --max-time 120 https://mirrors.ustc.edu.cn/misc/brew-install.sh' "$mode/$scenario: USTC 下载带相同超时限制"
      if [[ "$scenario" != both-download-timeout ]]; then
        e2e_assert_transcript_contains 'installer ustc NONINTERACTIVE=1 INTERACTIVE=unset' "$mode/$scenario: 镜像继承非交互模式"
      fi
    fi
    if [[ "$scenario" != download-failure && "$scenario" != empty-download && "$scenario" != download-timeout && "$scenario" != both-download-timeout ]]; then
      e2e_assert_transcript_contains 'installer official NONINTERACTIVE=1 INTERACTIVE=unset' "$mode/$scenario: 官方继承非交互模式"
    fi
    if [[ "$scenario" == download-timeout || "$scenario" == both-download-timeout ]]; then
      e2e_assert_contains "$E2E_RUN_OUTPUT" '下载失败（连接上限 10 秒，下载上限 120 秒）' "$mode/$scenario: 下载失败给出时限和重试提示"
      e2e_assert_transcript_not_contains 'installer official' "$mode/$scenario: 不执行官方超时响应"
    fi
    if [[ "$scenario" == both-download-timeout ]]; then
      e2e_assert_transcript_not_contains 'installer ustc' "$mode/$scenario: 不执行 USTC 超时响应"
    fi
    [[ ! -f "$E2E_TMP_ROOT/partial-download-executed" ]] || { e2e_fail '执行了下载不完整的脚本'; }
  done

  # dry-run 对尚不可用的 brew 也只能打印安装计划。
  rm -f "$E2E_TMP_ROOT/brew-ready"
  run_mode "$mode" ready --dry-run --yes
  e2e_assert_eq "$E2E_RUN_STATUS" 0 "$mode: 新机 Homebrew dry-run 成功"
  e2e_assert_contains "$E2E_RUN_OUTPUT" 'NONINTERACTIVE=1 /bin/bash' "$mode: dry-run 展示非交互安装模式"
  e2e_assert_contains "$E2E_RUN_OUTPUT" '--connect-timeout 10 --max-time 120 https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh' "$mode: dry-run 展示官方超时限制"
  e2e_assert_contains "$E2E_RUN_OUTPUT" '--connect-timeout 10 --max-time 120 https://mirrors.ustc.edu.cn/misc/brew-install.sh' "$mode: dry-run 展示 USTC 超时限制"
  e2e_assert_transcript_not_contains 'curl ' "$mode: dry-run 不下载安装脚本"
  e2e_assert_transcript_not_contains 'installer ' "$mode: dry-run 不执行安装器"
done

# 不传 --yes 时不主动注入 NONINTERACTIVE，也保留调用者的 INTERACTIVE。
export BOOTSTRAP_TEST_INSTALL_SCENARIO=official-success
rm -f "$E2E_TMP_ROOT/brew-ready"
run_confirm_mode local y
e2e_assert_eq "$E2E_RUN_STATUS" 0 '默认确认模式安装成功'
e2e_assert_transcript_contains 'installer official NONINTERACTIVE=unset INTERACTIVE=1' '默认模式保留用户交互设置'
e2e_assert_eq "$INTERACTIVE" 1 '安装器环境设置不修改父进程'
unset INTERACTIVE

# 全新机器未找到 brew 时，也必须保留用户指定的 tap 远程地址。
export TAP_REMOTE_URL='https://example.invalid/custom-tap.git'
rm -f "$E2E_TMP_ROOT/brew-ready"
for mode in local pipe; do
  run_mode "$mode" ready --dry-run --yes
  e2e_assert_eq "$E2E_RUN_STATUS" 0 "$mode: 全新机器可预演自定义 tap"
  e2e_assert_contains "$E2E_RUN_OUTPUT" "brew tap --custom-remote anzihenry/scripts $TAP_REMOTE_URL" "$mode: 预演保留 tap 地址及选项"
  e2e_assert_transcript_not_contains 'curl ' "$mode: 自定义 tap 预演不下载"
  e2e_assert_transcript_not_contains 'brew install ' "$mode: 自定义 tap 预演不安装"
done
unset TAP_REMOTE_URL

export MACOS_SCRIPTS_LOG_MAX_BYTES=256 MACOS_SCRIPTS_LOG_BACKUPS=2
for mode in local pipe; do
  run_mode "$mode" ready --dry-run
  e2e_assert_eq "$E2E_RUN_STATUS" 0 "$mode: 有界日志不影响入口执行"
  e2e_assert_contains "$E2E_RUN_OUTPUT" 'Bootstrap dry-run 完成' "$mode: 轮转后终端预演输出完整"
  for candidate in "$E2E_LOG_DIR/bootstrap.log" "$E2E_LOG_DIR/bootstrap.log".[0-9]*(N); do
    (( $(stat -f '%z' "$candidate") <= 256 )) || e2e_fail "$mode: 日志超过字节上限"
  done
  archives=("$E2E_LOG_DIR/bootstrap.log".[0-9]*(N))
  (( ${#archives[@]} <= 2 )) && e2e_pass "$mode: 归档份数受限" || e2e_fail "$mode: 归档份数超限"
done
unset MACOS_SCRIPTS_LOG_MAX_BYTES MACOS_SCRIPTS_LOG_BACKUPS

e2e_summary
printf '\nBootstrap guard passed: %d\n' "$E2E_PASS_COUNT"
