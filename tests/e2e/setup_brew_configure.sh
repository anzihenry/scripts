#!/bin/zsh
# filepath: tests/e2e/setup_brew_configure.sh
# E2E: setup brew configure --dry-run 真实流程。
# 回归护栏：homebrew-setup.sh 必须完整 source config_writer.sh，
# 否则 dry-run 会在 write_managed_block 处报 command not found
# （v0.5.0 发布门禁首次抓到该缺陷）。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/e2e_lib.sh"

REAL_GIT="$(command -v git)"
export REAL_GIT
e2e_begin "setup-brew-configure"

cd "$REPO_ROOT"

e2e_run_expect_success \
  "setup brew configure dry-run" \
  zsh bin/macos-scripts setup brew configure --dry-run

e2e_assert_contains "$E2E_RUN_OUTPUT" "系统环境预检通过" "setup brew 预检通过"
e2e_assert_contains "$E2E_RUN_OUTPUT" "配置完成" "setup brew 输出配置完成"
e2e_assert_not_contains "$E2E_RUN_OUTPUT" "command not found" "未出现缺失函数错误"
e2e_assert_file "$E2E_LOG_DIR/homebrew-setup.log" "setup brew 写入日志文件"
e2e_assert_file_contains "$E2E_LOG_DIR/homebrew-setup.log" '脚本: homebrew-setup.sh' "CLI 日志记录底层脚本名"
e2e_assert_file_contains "$E2E_LOG_DIR/homebrew-setup.log" '模式: dry-run' "CLI 预演日志正确标记模式"

e2e_assert_not_file "$E2E_HOME/.zshrc" "dry-run 不创建 .zshrc"
[[ ! -e "$E2E_CONFIG_DIR/backups" ]] && e2e_pass "dry-run 不创建备份或锁" || e2e_fail "dry-run 产生配置备份"

# 使用真实临时 Git 仓库验证 remote/config 还原，只拦截联网和故障注入。
export E2E_BREW_REPO="$E2E_TMP_ROOT/brew_repo"
export E2E_BREW_PREFIX="$E2E_TMP_ROOT/prefix"
CORE_REPO="$E2E_BREW_REPO/Library/Taps/homebrew/homebrew-core"
TEST_BIN="$E2E_TMP_ROOT/config-shims"
mkdir -p "$TEST_BIN" "$E2E_BREW_PREFIX/bin"
ln -s "$E2E_SHIMS_DIR/_recorder.sh" "$TEST_BIN/_recorder.sh"
ln -s "$E2E_SHIMS_DIR/brew" "$TEST_BIN/brew"
ln -s "$E2E_SHIMS_DIR/brew" "$E2E_BREW_PREFIX/bin/brew"
ln -s "$E2E_SHIMS_DIR/_recorder.sh" "$E2E_BREW_PREFIX/bin/_recorder.sh"
cat > "$TEST_BIN/git" <<'SHIM'
#!/bin/zsh
set -euo pipefail
source "${0:A:h}/_recorder.sh"
record_invocation "$@"
[[ "${1:-}" == -C ]] || exit 127
repo="$2"
case "${3:-}" in
  rev-parse) exec "$REAL_GIT" "$@" ;;
  remote)
    "$REAL_GIT" "$@"
    if [[ "$E2E_CONFIG_FAIL_STAGE" == brew-remote && "$repo" == "$E2E_BREW_REPO" ]] ||
       [[ "$E2E_CONFIG_FAIL_STAGE" == core-remote && "$repo" != "$E2E_BREW_REPO" ]]; then
      exit 1
    fi
    ;;
  ls-remote)
    if [[ "$E2E_CONFIG_FAIL_STAGE" == interrupt ]]; then
      kill -TERM "$PPID"
      exit 1
    fi
    if [[ "$E2E_CONFIG_FAIL_STAGE" == verify-brew || "$E2E_CONFIG_FAIL_STAGE" == restore-failure ]] ||
       [[ "$E2E_CONFIG_FAIL_STAGE" == verify-core && "$repo" != "$E2E_BREW_REPO" ]]; then
      exit 1
    fi
    printf '0123456789abcdef\tHEAD\n'
    ;;
  *) exit 127 ;;
esac
SHIM
cat > "$TEST_BIN/sleep" <<'SHIM'
#!/bin/zsh
exit 0
SHIM
cat > "$TEST_BIN/sed" <<'SHIM'
#!/bin/zsh
[[ "$E2E_CONFIG_FAIL_STAGE" != write-rc ]] || exit 1
exec /usr/bin/sed "$@"
SHIM
cat > "$TEST_BIN/cp" <<'SHIM'
#!/bin/zsh
if [[ "$E2E_CONFIG_FAIL_STAGE" == restore-failure && "${argv[-1]}" == *'.zshrc.restore.'* ]]; then exit 1; fi
if [[ "$E2E_CONFIG_FAIL_STAGE" == backup-failure && "${argv[-1]}" == */2 ]]; then exit 1; fi
exec /bin/cp "$@"
SHIM
chmod +x "$TEST_BIN/"git "$TEST_BIN/"sleep "$TEST_BIN/"sed "$TEST_BIN/"cp
export PATH="$TEST_BIN:$PATH"
export E2E_CONFIG_FAIL_STAGE=none

prepare_config_fixture() {
  "$REAL_GIT" init -q "$E2E_BREW_REPO"
  "$REAL_GIT" -C "$E2E_BREW_REPO" config remote.origin.url https://original.invalid/brew.git
  "$REAL_GIT" -C "$E2E_BREW_REPO" config remote.origin.pushurl ssh://original.invalid/brew.git
  "$REAL_GIT" init -q "$CORE_REPO"
  "$REAL_GIT" -C "$CORE_REPO" config remote.origin.url https://original.invalid/core.git
  /bin/cp -p "$E2E_BREW_REPO/.git/config" "$E2E_TMP_ROOT/brew-config-before"
  /bin/cp -p "$CORE_REPO/.git/config" "$E2E_TMP_ROOT/core-config-before"
  cat > "$E2E_HOME/.zshrc" <<'RC'
# 用户自定义配置
export USER_SETTING='keep me'
# >>> Homebrew Basic (managed by homebrew-config) >>>
export OLD_HOMEBREW_SETTING=1
# <<< Homebrew Basic (managed by homebrew-config) <<<
export USER_TAIL='keep this too'
RC
  chmod 640 "$E2E_HOME/.zshrc"
  /bin/cp -p "$E2E_HOME/.zshrc" "$E2E_TMP_ROOT/zshrc-before"
}

assert_config_restored() {
  local name="$1"
  cmp -s "$E2E_HOME/.zshrc" "$E2E_TMP_ROOT/zshrc-before" && e2e_pass "$name: .zshrc 原样恢复" || e2e_fail "$name: .zshrc 未恢复"
  cmp -s "$E2E_BREW_REPO/.git/config" "$E2E_TMP_ROOT/brew-config-before" && e2e_pass "$name: brew Git 配置原样恢复" || e2e_fail "$name: brew remote 未恢复"
  cmp -s "$CORE_REPO/.git/config" "$E2E_TMP_ROOT/core-config-before" && e2e_pass "$name: core Git 配置原样恢复" || e2e_fail "$name: core remote 未恢复"
  [[ "$(stat -L -f '%Lp' "$E2E_HOME/.zshrc")" == 640 ]] && e2e_pass "$name: 文件权限保留" || e2e_fail "$name: 权限变化"
  [[ ! -d "$E2E_CONFIG_DIR/backups/.homebrew-config.lock" ]] && e2e_pass "$name: 配置锁释放" || e2e_fail "$name: 锁残留"
}

prepare_config_fixture
e2e_run_expect_success "USTC 配置真实写入临时仓库" /bin/zsh bin/macos-scripts setup brew configure
e2e_assert_file_contains "$E2E_HOME/.zshrc" 'USER_TAIL' "成功时保留用户配置"
e2e_assert_file_contains "$E2E_HOME/.zshrc" 'https://mirrors.ustc.edu.cn/homebrew-bottles' "默认配置 USTC"
e2e_assert_eq "$("$REAL_GIT" -C "$E2E_BREW_REPO" remote get-url origin)" https://mirrors.ustc.edu.cn/brew.git "brew remote 切换成功"
e2e_assert_eq "$("$REAL_GIT" -C "$CORE_REPO" remote get-url origin)" https://mirrors.ustc.edu.cn/homebrew-core.git "core remote 切换成功"
e2e_assert_transcript_not_contains 'update-reset' "配置不重置仓库内容"
backup_dirs=("$E2E_CONFIG_DIR/backups/"homebrew-config.*(N))
e2e_assert_eq "${#backup_dirs[@]}" 0 "成功配置删除本次备份"
e2e_run_expect_success "重复配置仍成功" /bin/zsh bin/macos-scripts setup brew configure
e2e_assert_eq "$(grep -c '^# >>> Homebrew Basic ' "$E2E_HOME/.zshrc")" 1 "重复运行不叠加 Basic 配置块"
e2e_assert_eq "$(grep -c '^# >>> Homebrew Mirror ' "$E2E_HOME/.zshrc")" 1 "重复运行不叠加 Mirror 配置块"

for stage in write-rc brew-remote core-remote verify-brew verify-core interrupt; do
  export E2E_CONFIG_FAIL_STAGE="$stage"
  prepare_config_fixture
  e2e_run_expect_failure "$stage: 配置失败返回非零" /bin/zsh bin/macos-scripts setup brew configure
  e2e_assert_contains "$E2E_RUN_OUTPUT" '已恢复本次修改' "$stage: 输出回滚提示"
  assert_config_restored "$stage"
done

backup_dirs=("$E2E_CONFIG_DIR/backups/"homebrew-config.*(N))
e2e_assert_eq "${#backup_dirs[@]}" 6 "失败或中断保留各次备份"
e2e_assert_eq "$(stat -f '%Lp' "${backup_dirs[1]}")" 700 "备份目录仅当前用户可访问"
cmp -s "${backup_dirs[1]}/1" "$E2E_TMP_ROOT/zshrc-before" && e2e_pass "备份包含原始 .zshrc" || e2e_fail "备份内容不符"
export E2E_CONFIG_FAIL_STAGE=none
e2e_run_expect_success "失败后重新配置成功" /bin/zsh bin/macos-scripts setup brew configure
for backup_dir in "${backup_dirs[@]}"; do
  e2e_assert_file "$backup_dir/manifest.tsv" "后续成功保留此前失败的备份"
done
backup_dirs=("$E2E_CONFIG_DIR/backups/"homebrew-config.*(N))
e2e_assert_eq "${#backup_dirs[@]}" 6 "后续成功仅清理本次备份"

# 原来没有 .zshrc：失败后恢复为不存在，而非遗留新配置。
export E2E_CONFIG_FAIL_STAGE=verify-brew
prepare_config_fixture
rm "$E2E_HOME/.zshrc"
e2e_run_expect_failure "原本无 .zshrc 时失败" /bin/zsh bin/macos-scripts setup brew configure
e2e_assert_not_file "$E2E_HOME/.zshrc" "失败后移除本次创建的 .zshrc"

# 符号链接写入与还原作用于目标文件，链接本身保持不变。
prepare_config_fixture
mv "$E2E_HOME/.zshrc" "$E2E_TMP_ROOT/linked zshrc"
ln -s "$E2E_TMP_ROOT/linked zshrc" "$E2E_HOME/.zshrc"
e2e_run_expect_failure "符号链接配置失败" /bin/zsh bin/macos-scripts setup brew configure
[[ -L "$E2E_HOME/.zshrc" ]] && e2e_pass ".zshrc 符号链接保留" || e2e_fail "符号链接被替换"
assert_config_restored symlink
rm "$E2E_HOME/.zshrc"

# 缺失结束标记时提前拒绝，不能范围删除用户文件尾部。
export E2E_CONFIG_FAIL_STAGE=none
prepare_config_fixture
printf '# >>> Homebrew Mirror (managed by homebrew-config) >>>\nKEEP_TAIL=1\n' >> "$E2E_HOME/.zshrc"
/bin/cp -p "$E2E_HOME/.zshrc" "$E2E_TMP_ROOT/zshrc-before"
e2e_run_expect_failure "损坏的管理块被拒绝" /bin/zsh bin/macos-scripts setup brew configure
assert_config_restored malformed

prepare_config_fixture
export E2E_CONFIG_FAIL_STAGE=backup-failure
e2e_run_expect_failure "备份失败时中止" /bin/zsh bin/macos-scripts setup brew configure
e2e_assert_contains "$E2E_RUN_OUTPUT" '无法备份配置' "备份失败提示权限检查"
assert_config_restored backup-failure

export E2E_CONFIG_FAIL_STAGE=none
prepare_config_fixture
mkdir "$E2E_CONFIG_DIR/backups/.homebrew-config.lock"
e2e_run_expect_failure "已有配置锁时拒绝并发写入" /bin/zsh bin/macos-scripts setup brew configure
[[ -d "$E2E_CONFIG_DIR/backups/.homebrew-config.lock" ]] && e2e_pass "不会删除其他配置进程的锁" || e2e_fail "误删配置锁"
rmdir "$E2E_CONFIG_DIR/backups/.homebrew-config.lock"
assert_config_restored concurrent

# API 模式未安装 core tap 时，不强制克隆整个仓库。
prepare_config_fixture
rm -rf "$CORE_REPO"
e2e_run_expect_success "无 core tap 仍可配置镜像" /bin/zsh bin/macos-scripts setup brew configure
[[ ! -d "$CORE_REPO" ]] && e2e_pass "未创建额外 core 仓库" || e2e_fail "意外创建 core 仓库"
e2e_assert_transcript_not_contains 'git clone' "配置不克隆仓库"

# 回滚自身失败时必须保留备份并清楚告知，不能宣称已全部恢复。
prepare_config_fixture
export E2E_CONFIG_FAIL_STAGE=restore-failure
e2e_run_expect_failure "模拟回滚写入失败" /bin/zsh bin/macos-scripts setup brew configure
e2e_assert_contains "$E2E_RUN_OUTPUT" '部分文件未能自动恢复' "回滚失败给出手动恢复提示"
e2e_assert_not_contains "$E2E_RUN_OUTPUT" '已恢复本次修改' "回滚失败不谎报成功"
backup_dirs=("$E2E_CONFIG_DIR/backups/"homebrew-config.*(N))
(( ${#backup_dirs[@]} > 0 )) && e2e_pass "回滚失败仍保留备份" || e2e_fail "备份丢失"

e2e_summary
