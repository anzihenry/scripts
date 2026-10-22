#!/bin/zsh
# filepath: tests/reliability_guard.sh
# 真实子进程/临时文件验证并发、条件调用、信号、事务提交及无副作用预览。
set -euo pipefail
setopt no_bg_nice
ROOT="${0:A:h:h}"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/reliability.XXXXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home" TMPDIR="$SANDBOX/tmp"
export MACOS_SCRIPTS_CONFIG_DIR="$SANDBOX/config" MACOS_SCRIPTS_LOG_DIR="$SANDBOX/log"
mkdir -p "$HOME" "$TMPDIR"
source "$ROOT/lib/colors.sh"
source "$ROOT/lib/utils.sh"
source "$ROOT/lib/config_writer.sh"
PASS_COUNT=0
start_background() { "$@" & LAST_CHILD_PID=$!; }
pass() { print "[PASS] $1"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { print -u2 "[FAIL] $1"; exit 1; }

produce_many_lines() { repeat 20000 print 'first'; }
[[ "$(first_line produce_many_lines)" == first ]] || fail 'first_line 大输出失败'
pass 'first_line 消费全部输入，不产生 SIGPIPE'

(
    source "$ROOT/setup/lib/setup_runtime.sh"
    install_node() { return 7; }
    install_python() { fail 'Node 失败后不能执行 Python'; }
    code=0
    if run_language_environment_setup; then fail '条件调用吞掉错误'; else code=$?; fi
    [[ "$code" == 7 ]] || fail '原始退出码丢失'
    run_language_environment_setup || code=$?
    [[ "$code" == 7 ]] || fail 'OR 调用吞掉错误'
)
pass '流程在 if 和 OR 条件下保留失败并停止后续步骤'

code=0
/bin/zsh -e -c 'source "$1/setup/lib/setup_runtime.sh"; install_node() { return 7; }; run_language_environment_setup; print BAD' zsh "$ROOT" > "$SANDBOX/direct.log" 2>&1 || code=$?
[[ "$code" == 7 && ! -s "$SANDBOX/direct.log" ]] || fail '直接调用未立即失败'
pass '直接调用与条件调用的错误传播一致'

(
    source "$ROOT/setup/lib/setup_runtime.sh"
    parse_setup_options --modules python,python
    calls=()
    install_node() { fail '未选择 Node 却被执行'; }
    install_python() { calls+=(python); }
    install_ruby() { fail '未选择 Ruby 却被执行'; }
    install_go() { fail '未选择 Go 却被执行'; }
    config_android_and_java() { fail '未选择 Android 却被执行'; }
    run_language_environment_setup
    [[ "${calls[*]}" == python ]] || fail '模块去重或执行选择错误'
)
pass '选择模块只执行对应语言，重复参数不重复执行'

(
    source "$ROOT/setup/lib/setup_lang_env.sh"
    brew() { return 0; }
    update_shell_config() { :; }
    nvm() { return 0; }
    npm() { [[ "$1 $2" == 'config get' ]] && return 9; fail '查询失败不得写 npm 配置'; }
    install_node && fail 'npm 查询失败未传播'
    true
)
pass 'npm 查询失败不会被 local 声明掩盖'

(
    source "$ROOT/maintain/lib/brew_updater_casks.sh"
    brew() { return 8; }
    set +e
    get_outdated_casks >/dev/null 2>&1
    [[ ! -o errexit ]] || fail 'helper 修改了调用方 errexit'
)
pass '捕获预期失败不修改调用方 Shell 选项'

typeset -a writers=()
for index in {1..12}; do
    /bin/zsh -c 'source "$1/lib/colors.sh"; source "$1/lib/config_writer.sh"; write_managed_block "$2" "$3" guard "export VALUE_$3=$3"' zsh "$ROOT" "$HOME/.zshrc" "$index" &
    writers+=("$!")
done
for writer in "${writers[@]}"; do wait "$writer" || fail '并发写入失败'; done
[[ "$(grep -c '^export VALUE_' "$HOME/.zshrc")" == 12 ]] || fail '并发更新丢失'
pass '12 个独立进程修改同一配置，所有更新均保留'

ln -s "$HOME/.zshrc" "$SANDBOX/link"
(
    resource_lock_acquire "$HOME/.zshrc"
    with_resource_lock "$SANDBOX/link" write_managed_block "$HOME/.zshrc" nested guard 'export NESTED=1' || fail '嵌套锁死锁'
    MACOS_SCRIPTS_LOCK_TIMEOUT=0 /bin/zsh -c 'source "$1/lib/colors.sh"; source "$1/lib/resource_lock.sh"; resource_lock_acquire "$2"' zsh "$ROOT" "$SANDBOX/link" 2>/dev/null && fail '竞争进程绕过资源锁'
    true
)
pass '符号链接共用资源锁，同步嵌套可重入，竞争进程被拒绝'

cat > "$SANDBOX/holder.sh" <<'ZSH'
#!/bin/zsh
source "$1/lib/colors.sh"
source "$1/lib/resource_lock.sh"
resource_lock_acquire "$2" || exit 1
print ready > "$3"
while true; do sleep 0.05; done
ZSH
start_background /bin/zsh "$SANDBOX/holder.sh" "$ROOT" "$SANDBOX/resource" "$SANDBOX/ready"
holder=$LAST_CHILD_PID
for index in {1..100}; do [[ ! -f "$SANDBOX/ready" ]] || break; sleep 0.05; done
[[ -f "$SANDBOX/ready" ]] || { kill "$holder"; fail '等待锁持有进程超时'; }
kill -KILL "$holder"
wait "$holder" 2>/dev/null || :
MACOS_SCRIPTS_LOCK_TIMEOUT=0 /bin/zsh -c 'source "$1/lib/colors.sh"; source "$1/lib/resource_lock.sh"; resource_lock_acquire "$2"' zsh "$ROOT" "$SANDBOX/resource" || fail '强制终止后无法重入'
pass '持锁进程 SIGKILL 后内核释放锁，无需删除锁文件'

# 真实 Homebrew 配置事务失败回滚时，其他入口的写入必须排队至回滚结束。
mkdir -p "$SANDBOX/tx-home" "$SANDBOX/brew"
print 'export ORIGINAL=1' > "$SANDBOX/tx-home/.zshrc"
git -C "$SANDBOX/brew" init -q
cat > "$SANDBOX/transaction.sh" <<'ZSH'
#!/bin/zsh
set -euo pipefail
source "$1/lib/colors.sh"
source "$1/lib/utils.sh"
source "$1/lib/config_writer.sh"
source "$1/setup/lib/homebrew_config.sh"
export HOME="$2/tx-home" MACOS_SCRIPTS_CONFIG_DIR="$2/tx-state"
TEST_ROOT="$2"
brew() { print "$TEST_ROOT/brew"; }
homebrew_configuration_current() { return 1; }
configure_homebrew_shellenv() {
    write_managed_block "$HOME/.zshrc" rollback guard 'export SHOULD_ROLL_BACK=1' || return 1
    print ready > "$TEST_ROOT/tx-ready"
}
configure_homebrew_mirror_exports() { sleep 1; return 8; }
run_homebrew_config_transaction brew
ZSH
start_background /bin/zsh "$SANDBOX/transaction.sh" "$ROOT" "$SANDBOX" > "$SANDBOX/transaction.log" 2>&1
transaction=$LAST_CHILD_PID
for index in {1..100}; do [[ ! -f "$SANDBOX/tx-ready" ]] || break; sleep 0.05; done
[[ -f "$SANDBOX/tx-ready" ]] || { kill "$transaction" 2>/dev/null || :; fail '事务未到达注入失败点'; }
/bin/zsh -c 'source "$1/lib/colors.sh"; source "$1/lib/config_writer.sh"; write_managed_block "$2" parallel guard "export PARALLEL=1"' zsh "$ROOT" "$SANDBOX/tx-home/.zshrc" || fail '事务后写入失败'
code=0
wait "$transaction" || code=$?
[[ "$code" != 0 ]] || fail '事务应失败'
grep -q 'export ORIGINAL=1' "$SANDBOX/tx-home/.zshrc" || fail '原内容未恢复'
grep -q 'export PARALLEL=1' "$SANDBOX/tx-home/.zshrc" || fail '回滚覆盖并发更新'
! grep -q SHOULD_ROLL_BACK "$SANDBOX/tx-home/.zshrc" || fail '失败内容未回滚'
pass 'Homebrew 回滚与其他配置入口互斥，不覆盖排队的更新'

printf '[global]\nindex-url = old\ntrusted-host = old\n' > "$SANDBOX/pip.conf"
cp "$SANDBOX/pip.conf" "$SANDBOX/pip.before"
(
    count=0
    update_ini_candidate() { count=$((count+1)); [[ "$count" != 2 ]] || return 6; print partial > "$1"; }
    set_ini_values "$SANDBOX/pip.conf" global index-url new trusted-host new && fail '第二键失败未传播'
    true
)
cmp -s "$SANDBOX/pip.conf" "$SANDBOX/pip.before" || fail '批量 INI 失败污染原文件'
pass '多键配置第二步失败时保留原文件'

(
    source "$ROOT/lib/workflow.sh"
    one() { :; }
    two() { return 12; }
    three() { fail '失败后执行了下一阶段'; }
    code=0
    output="$(run_stages 已完成 one 故障 two 待处理 three 2>&1)" || code=$?
    [[ "$code" == 12 && "$output" == *'未执行: 待处理'* && "$output" == *'已完成: 已完成'* ]] || fail '摘要或退出码错误'
)
pass '阶段摘要包含已完成、失败和未执行，保留退出码'

code=0
output="$(/bin/zsh -c '
    source "$1/lib/utils.sh"
    ml_locked_write() { [[ "$3" == true ]]; }
    enable_log_capture "$2" || exit 1
    print example
    exit 7
' zsh "$ROOT" "$SANDBOX/recorder.log" 2>&1)" || code=$?
[[ "$code" == 7 && "$output" == *'运行日志不完整'* ]] || fail '日志失败覆盖业务退出码或缺少摘要'
pass '日志记录失败报告不完整，同时保留业务退出码'

for entry in "$ROOT/setup/macos-setup.sh" "$ROOT/bin/macos-scripts"; do
    args=(--dry-run --modules node,python)
    [[ "$entry" != */bin/* ]] || args=(setup packages "${args[@]}")
    output="$(/bin/zsh "$entry" "${args[@]}" 2>&1)" || fail '模块预览失败'
    [[ "$output" == *'选择模块: node python'* ]] || fail '模块解析不一致'
done
for entry in "$ROOT/setup/ohmyzsh-setup.sh" "$ROOT/bin/macos-scripts"; do
    args=(--dry-run)
    [[ "$entry" != */bin/* ]] || args=(setup shell --dry-run)
    /bin/zsh "$entry" "${args[@]}" >/dev/null 2>&1 || fail '终端预览失败'
done
[[ ! -e "$MACOS_SCRIPTS_CONFIG_DIR" && ! -e "$MACOS_SCRIPTS_LOG_DIR" && ! -e "$HOME/.oh-my-zsh" ]] || fail '预览产生副作用'
pass 'CLI 和独立入口预览模块一致，不创建配置、日志或安装目录'

for entry in "$ROOT/setup/macos-setup.sh" "$ROOT/bin/macos-scripts"; do
    args=(--modules node,unknown)
    [[ "$entry" != */bin/* ]] || args=(setup packages "${args[@]}")
    /bin/zsh "$entry" "${args[@]}" >/dev/null 2>&1 && fail '接受未知模块'
done
pass 'CLI 和独立入口在执行前拒绝未知模块'

for option in --version --volume --installer-path; do
    /bin/zsh "$ROOT/maintain/macos_sys_usb_maker.sh" create "$option" > "$SANDBOX/missing.log" 2>&1 && fail '缺值参数被接受'
    grep -q '缺少参数值' "$SANDBOX/missing.log" || fail '缺值参数诊断不清晰'
done
pass '安装器缺值参数立即报错，不进入 shift 重试循环'

# 真实安装器入口的信号路径；命令桩替代 softwareupdate，禁止触碰真实磁盘。
mkdir -p "$SANDBOX/bin"
cat > "$SANDBOX/bin/sw_vers" <<'ZSH'
#!/bin/zsh
print 14.6.1
ZSH
cat > "$SANDBOX/bin/softwareupdate" <<'ZSH'
#!/bin/zsh
print ready > "$SIGNAL_READY"
sleep 1
exit 0
ZSH
cat > "$SANDBOX/bin/hdiutil" <<'ZSH'
#!/bin/zsh
exit 1
ZSH
chmod +x "$SANDBOX/bin/"*
for signal in TERM INT HUP; do
    case "$signal" in TERM) expected=143 ;; INT) expected=130 ;; HUP) expected=129 ;; esac
    export SIGNAL_READY="$SANDBOX/signal-$signal"
    PATH="$SANDBOX/bin:$PATH" /bin/zsh "$ROOT/maintain/macos_sys_usb_maker.sh" download --version 14.6.1 --force > "$SANDBOX/signal-$signal.log" 2>&1 &
    process=$!
    for index in {1..100}; do [[ ! -f "$SIGNAL_READY" ]] || break; sleep 0.05; done
    [[ -f "$SIGNAL_READY" ]] || { kill "$process" 2>/dev/null || :; fail '安装器未到达下载阶段'; }
    kill -"$signal" "$process"
    code=0
    wait "$process" || code=$?
    [[ "$code" == "$expected" ]] || fail "信号 $signal 退出码为 $code"
    ! grep -q '校验下载结果' "$SANDBOX/signal-$signal.log" || fail '收到信号后继续执行'
done
pass '实际安装器入口收到 TERM/INT/HUP 后退出，重跑可重新获取锁'
print "\nReliability guard passed: $PASS_COUNT"
