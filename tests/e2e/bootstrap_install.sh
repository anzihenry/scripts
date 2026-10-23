#!/bin/zsh
# filepath: tests/e2e/bootstrap_install.sh
# E2E: bootstrap/install.sh 真实流程（brew / curl / macos-scripts 命令桩）。
# 断言 tap + install 调用、日志文件写入与整体退出码。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/e2e_lib.sh"

e2e_begin "bootstrap-install"

cd "$REPO_ROOT"

assert_failure_summary() {
  local stage="$1"
  e2e_assert_contains "$E2E_RUN_OUTPUT" "bootstrap 失败，阶段: $stage" "失败摘要指出 $stage"
  e2e_assert_contains "$E2E_RUN_OUTPUT" "日志文件位置: $E2E_LOG_DIR/bootstrap.log" "失败摘要给出日志位置"
  e2e_assert_contains "$E2E_RUN_OUTPUT" '恢复建议: 查看上方原始错误并修复问题后，重新运行原 bootstrap 命令' "失败摘要给出恢复建议"
  e2e_assert_eq "$(grep -c 'bootstrap 失败，阶段:' <<< "$E2E_RUN_OUTPUT")" 1 "失败摘要只输出一次"
}

e2e_run_expect_success \
  "bootstrap 真实安装流程" \
  zsh bootstrap/install.sh --yes --skip-configure

e2e_assert_transcript_contains \
  "brew tap anzihenry/scripts https://github.com/anzihenry/scripts" \
  "bootstrap 调用 brew tap"
e2e_assert_transcript_contains \
  "brew install anzihenry/scripts/macos-scripts" \
  "bootstrap 调用 brew install"
e2e_assert_contains "$E2E_RUN_OUTPUT" "Bootstrap 完成" "bootstrap 输出完成"
e2e_assert_file "$E2E_LOG_DIR/bootstrap.log" "bootstrap 写入日志文件"
e2e_assert_transcript_contains 'macos-scripts --version' "skip-configure 也验证 CLI 能运行"
e2e_assert_contains "$E2E_RUN_OUTPUT" '当前 CLI 版本: macos-scripts 0.5.0' "显示实际 CLI 版本"
e2e_assert_not_contains "$E2E_RUN_OUTPUT" 'bootstrap 失败，阶段:' "成功时不输出失败摘要"
e2e_assert_contains "$E2E_RUN_OUTPUT" 'Homebrew 路径:' "成功摘要显示实际 Homebrew 路径"
e2e_assert_contains "$E2E_RUN_OUTPUT" "macos-scripts 路径: $E2E_SHIMS_DIR/macos-scripts" "成功摘要显示实际 CLI 路径"
e2e_assert_contains "$E2E_RUN_OUTPUT" 'CLI 实际版本: macos-scripts 0.5.0' "成功摘要显示实际版本"
e2e_assert_contains "$E2E_RUN_OUTPUT" 'USTC 配置: 已跳过（--skip-configure）' "成功摘要明确配置已跳过"
e2e_assert_contains "$E2E_RUN_OUTPUT" "日志目录: $E2E_LOG_DIR" "成功摘要显示自定义统一日志目录"

export E2E_BREW_INSTALLED_FORMULA=macos-scripts
export E2E_CLI_VERSION_OUTPUT='macos-scripts 0.1.0'
: > "$E2E_TRANSCRIPT"
e2e_run_expect_success "已安装时继续配置" zsh bootstrap/install.sh --yes
e2e_assert_contains "$E2E_RUN_OUTPUT" '跳过安装和升级' "已安装时说明跳过"
e2e_assert_transcript_not_contains 'brew install ' "已安装时不重新安装"
e2e_assert_transcript_not_contains 'brew upgrade ' "已安装时不升级"
e2e_assert_transcript_contains 'macos-scripts setup brew configure' "已安装时仍执行配置"
e2e_assert_transcript_order "先验证 CLI 再执行配置" 'macos-scripts --version' 'macos-scripts setup brew configure'
e2e_assert_contains "$E2E_RUN_OUTPUT" '当前 CLI 版本: macos-scripts 0.1.0' "旧版本也可继续配置"
e2e_assert_contains "$E2E_RUN_OUTPUT" 'USTC 配置: 已完成' "成功摘要明确配置已完成"

: > "$E2E_TRANSCRIPT"
e2e_run_expect_success "已安装时 dry-run 成功" zsh bootstrap/install.sh --dry-run
e2e_assert_contains "$E2E_RUN_OUTPUT" '跳过安装和升级' "dry-run 说明跳过"
e2e_assert_not_contains "$E2E_RUN_OUTPUT" 'brew upgrade' "dry-run 不计划升级"
e2e_assert_not_contains "$E2E_RUN_OUTPUT" 'brew install' "dry-run 不计划重新安装"
e2e_assert_contains "$E2E_RUN_OUTPUT" "[dry-run] 将执行 'macos-scripts setup brew configure'" "dry-run 仍计划配置"
e2e_assert_transcript_not_contains 'macos-scripts setup brew configure' "dry-run 不实际执行配置"
e2e_assert_contains "$E2E_RUN_OUTPUT" '将执行 macos-scripts --version' "dry-run 展示版本检查计划"
e2e_assert_transcript_not_contains 'macos-scripts --version' "dry-run 不实际运行版本检查"
e2e_assert_not_contains "$E2E_RUN_OUTPUT" 'CLI 实际版本:' "预演不伪报 CLI 实际版本"
e2e_assert_not_contains "$E2E_RUN_OUTPUT" 'USTC 配置: 已完成' "预演不伪报配置完成"
e2e_assert_contains "$E2E_RUN_OUTPUT" '未实际执行安装、CLI 校验或 USTC 配置' "预演结果明确说明未执行"

export E2E_CLI_VERSION_STATUS=42
for installed in '' macos-scripts; do
  export E2E_BREW_INSTALLED_FORMULA="$installed"
  for skip_configure in false true; do
    : > "$E2E_TRANSCRIPT"
    args=(--yes)
    [[ "$skip_configure" == false ]] || args+=(--skip-configure)
    e2e_run_expect_failure "版本检查失败中止（已安装=${installed:-否}, skip=$skip_configure）" zsh bootstrap/install.sh "${args[@]}"
    e2e_assert_contains "$E2E_RUN_OUTPUT" 'brew reinstall anzihenry/scripts/macos-scripts' "版本检查失败给出修复命令"
    e2e_assert_contains "$E2E_RUN_OUTPUT" "$E2E_LOG_DIR/bootstrap.log" "版本检查失败提示日志路径"
    e2e_assert_contains "$E2E_RUN_OUTPUT" 'CLI version check failed' "保留 CLI 原始错误输出"
    e2e_assert_transcript_not_contains 'macos-scripts setup brew configure' "版本检查失败不执行配置"
    e2e_assert_not_contains "$E2E_RUN_OUTPUT" 'Bootstrap 完成' "版本检查失败不报告完成"
    [[ ! -e "$E2E_CONFIG_DIR/.bootstrap.lock" ]] && e2e_pass "CLI 检查失败释放运行锁" || e2e_fail "CLI 检查失败后锁残留"
    assert_failure_summary '验证 macos-scripts CLI'
  done
done

unset E2E_CLI_VERSION_STATUS
export E2E_CLI_CONFIG_STATUS=7
e2e_run_expect_failure "配置阶段失败中止 bootstrap" zsh bootstrap/install.sh --yes
e2e_assert_contains "$E2E_RUN_OUTPUT" 'CLI 配置阶段失败' "保留配置阶段失败提示"
[[ ! -e "$E2E_CONFIG_DIR/.bootstrap.lock" ]] && e2e_pass "配置失败释放运行锁" || e2e_fail "配置失败后锁残留"
assert_failure_summary '配置 Homebrew（USTC）'

unset E2E_CLI_CONFIG_STATUS
export E2E_BREW_INSTALLED_FORMULA=''
for failed_command in tap install; do
  export E2E_BREW_FAIL_COMMAND="$failed_command"
  : > "$E2E_TRANSCRIPT"
  e2e_run_expect_failure "brew $failed_command 失败中止 bootstrap" zsh bootstrap/install.sh --yes
  e2e_assert_transcript_not_contains 'macos-scripts --version' "brew $failed_command 失败不继续验证 CLI"
  e2e_assert_not_contains "$E2E_RUN_OUTPUT" 'Bootstrap 完成' "brew $failed_command 失败不报告完成"
  [[ ! -e "$E2E_CONFIG_DIR/.bootstrap.lock" ]] && e2e_pass "brew $failed_command 失败释放运行锁" || e2e_fail "brew $failed_command 失败后锁残留"
  e2e_assert_contains "$E2E_RUN_OUTPUT" "brew $failed_command failed (e2e stub)" "保留 brew $failed_command 原始错误"
  if [[ "$failed_command" == tap ]]; then
    assert_failure_summary '添加 tap'
  else
    assert_failure_summary '安装 macos-scripts'
  fi
done

unset E2E_BREW_FAIL_COMMAND
export E2E_CLI_EXPECT_LOG_DIR="$E2E_HOME/Library/Logs/macos-scripts"
e2e_run_expect_success "未设置目录时 bootstrap 将默认日志目录传递给 CLI" env -u MACOS_SCRIPTS_LOG_DIR zsh bootstrap/install.sh --yes
e2e_assert_file "$E2E_CLI_EXPECT_LOG_DIR/bootstrap.log" "默认 bootstrap 日志写入统一目录"
e2e_assert_contains "$E2E_RUN_OUTPUT" "日志目录: $E2E_CLI_EXPECT_LOG_DIR" "默认成功摘要显示统一日志目录"

export E2E_CLI_EXPECT_LOG_DIR="$E2E_TMP_ROOT/logs with spaces"
e2e_run_expect_success "带空格的自定义日志目录传递给 CLI" env MACOS_SCRIPTS_LOG_DIR="$E2E_CLI_EXPECT_LOG_DIR" zsh bootstrap/install.sh --yes
e2e_assert_file "$E2E_CLI_EXPECT_LOG_DIR/bootstrap.log" "自定义日志写入指定目录"

e2e_summary
