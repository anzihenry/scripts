#!/bin/zsh
# filepath: tests/zsh_migration_guard.sh
# 验证 Bash -> Zsh 迁移中语法检查无法发现的运行时差异。
set -euo pipefail

REPO_ROOT="${0:A:h:h}"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/zsh-migration.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
PASS_COUNT=0
pass() { printf '[PASS] %s\n' "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { printf '[FAIL] %s\n' "$1" >&2; exit 1; }

# 交互菜单使用 Zsh 的一基数组，保留原来返回零基选项编号的接口。
NO_COLOR=true
source "$REPO_ROOT/lib/colors.sh"
menu_output="$(select_option '选择' '第一项' '第二项' <<< '2')"
[[ "$menu_output" == *'1) 第一项'* && "$menu_output" == *'2) 第二项'* && "$menu_output" == *': 1' ]] || fail '菜单索引'
pass '菜单显示一基编号并保留返回值接口'
[[ "$(/bin/zsh "$REPO_ROOT/lib/colors.sh" check)" == *'颜色输出'* ]] || fail '颜色库直接执行'
pass '颜色库区分直接执行与 source'

# 不能在函数返回时删除 E2E 沙箱；进程退出后必须清理。
e2e_sandbox="$(/bin/zsh -eu -o pipefail -c '
  source "$1/tests/e2e/e2e_lib.sh"
  e2e_begin migration
  [[ -d "$E2E_TMP_ROOT" ]]
  printf "%s" "$E2E_TMP_ROOT"
' zsh "$REPO_ROOT")"
[[ -n "$e2e_sandbox" && ! -d "$e2e_sandbox" ]] || fail 'E2E 清理时机'
pass 'E2E 沙箱在 begin 返回后保留，进程退出后清理'

# 使用有空格的路径验证 lint 的文件发现和错误退出码。
mkdir -p "$SANDBOX/with space"
printf '#!/bin/zsh\nprint ok\n' > "$SANDBOX/with space/good.sh"
/bin/zsh "$REPO_ROOT/lint/lint_shell.sh" "$SANDBOX/with space" > /dev/null
pass 'lint 支持含空格的路径'
printf '#!/bin/bash\n' > "$SANDBOX/with space/bad.sh"
if /bin/zsh "$REPO_ROOT/lint/lint_shell.sh" "$SANDBOX/with space" > /dev/null 2>&1; then fail 'lint 未拒绝 Bash'; fi
pass 'lint 拒绝非 Zsh shebang'
printf '#!/bin/zsh\nif then\n' > "$SANDBOX/with space/bad.sh"
if /bin/zsh "$REPO_ROOT/lint/lint_shell.sh" "$SANDBOX/with space" > /dev/null 2>&1; then fail 'lint 未拒绝语法错误'; fi
pass 'lint 拒绝 Zsh 语法错误'

# 在隔离 HOME 中运行完整 SSH 配置流程，不访问真实 Git/SSH/网络。
mkdir -p "$SANDBOX/shims" "$SANDBOX/home with space"
cat > "$SANDBOX/shims/git" <<'EOF'
#!/bin/zsh
set -euo pipefail
[[ $# == 3 ]] && exit 1
exit 0
EOF
cat > "$SANDBOX/shims/ssh-keygen" <<'EOF'
#!/bin/zsh
set -euo pipefail
[[ "${1:-}" != -l ]] || { printf '256 SHA256:FAKE comment\n'; exit 0; }
[[ "${1:-}" != -y ]] || { printf 'ssh-ed25519 FAKE\n'; exit 0; }
while (( $# > 0 )); do
  if [[ "$1" == -f ]]; then
    printf private > "$2"
    printf 'ssh-ed25519 FAKE test@example.com\n' > "$2.pub"
    exit 0
  fi
  shift
done
exit 1
EOF
cat > "$SANDBOX/shims/ssh" <<'EOF'
#!/bin/zsh
printf 'successfully authenticated\n'
EOF
chmod +x "$SANDBOX/shims/"*
env HOME="$SANDBOX/home with space" PATH="$SANDBOX/shims:$PATH" \
  MACOS_SCRIPTS_LOG_DIR="$SANDBOX/logs" MACOS_SCRIPTS_CONFIG_DIR="$SANDBOX/config" \
  /bin/zsh "$REPO_ROOT/setup/git_forge_ssh_setup.sh" --skip-upload <<< 'test@example.com' > "$SANDBOX/ssh-output" 2>&1
[[ -f "$SANDBOX/home with space/.ssh/id_ed25519_github_personal.pub" ]] || fail 'SSH 密钥创建'
grep -q 'Host github-personal' "$SANDBOX/home with space/.ssh/config" || fail 'SSH 配置创建'
pass 'SSH 邮箱输入、密钥创建和配置流程可在 Zsh 中运行'

# 已有密钥时从 stdin 读取单字符，不能误用 Zsh 默认的终端输入。
env HOME="$SANDBOX/home with space" PATH="$SANDBOX/shims:$PATH" \
  MACOS_SCRIPTS_LOG_DIR="$SANDBOX/logs" MACOS_SCRIPTS_CONFIG_DIR="$SANDBOX/config" \
  /bin/zsh "$REPO_ROOT/setup/git_forge_ssh_setup.sh" --skip-upload <<< 'N' > "$SANDBOX/ssh-reuse-output" 2>&1
[[ "$(<"$SANDBOX/home with space/.ssh/id_ed25519_github_personal")" == private ]] || fail 'SSH 密钥复用'
pass 'SSH 重复执行直接复用现有密钥'

# 令牌静默输入也必须使用 Zsh read 语义；全部外部请求使用桩。
cat > "$SANDBOX/shims/python3" <<'EOF'
#!/bin/zsh
if [[ "$*" == *'keys=json.load'* ]]; then printf '0\n'; exit 1; fi
printf '{"key":"ssh-ed25519 FAKE","title":"migration"}'
EOF
cat > "$SANDBOX/shims/curl" <<'EOF'
#!/bin/zsh
set -euo pipefail
while (( $# > 0 )); do
  if [[ "$1" == --config ]]; then
    grep -q 'Authorization: token fake-migration-token' "$2"
    if grep -q '^data =' "$2"; then
      : > "$MIGRATION_UPLOAD_MARKER"
      printf '\n201'
    else
      printf '[]\n200'
    fi
    exit 0
  fi
  shift
done
exit 1
EOF
chmod +x "$SANDBOX/shims/python3" "$SANDBOX/shims/curl"
env HOME="$SANDBOX/home with space" PATH="$SANDBOX/shims:$PATH" \
  MACOS_SCRIPTS_LOG_DIR="$SANDBOX/logs" MACOS_SCRIPTS_CONFIG_DIR="$SANDBOX/config" \
  MIGRATION_UPLOAD_MARKER="$SANDBOX/uploaded" \
  /bin/zsh "$REPO_ROOT/setup/git_forge_ssh_setup.sh" --type work <<< $'test@example.com\nfake-migration-token' > "$SANDBOX/ssh-upload-output" 2>&1
[[ -f "$SANDBOX/uploaded" ]] || fail 'SSH 令牌输入'
pass 'SSH 静默读取令牌并通过模拟 API 完成上传'

if ssh_eof_output="$(env HOME="$SANDBOX/eof-home" PATH="$SANDBOX/shims:$PATH" \
  MACOS_SCRIPTS_LOG_DIR="$SANDBOX/logs" MACOS_SCRIPTS_CONFIG_DIR="$SANDBOX/config" \
  /bin/zsh "$REPO_ROOT/setup/git_forge_ssh_setup.sh" --type personal --skip-upload < /dev/null 2>&1)"; then
  fail 'SSH EOF 未返回失败'
fi
[[ "$ssh_eof_output" == *'无法读取邮箱输入'* ]] || fail 'SSH EOF 诊断'
pass 'SSH stdin 结束时返回失败并给出诊断'

# 安装 helper 的成功/重试路径不得给 Zsh 只读变量 status 赋值。
source "$REPO_ROOT/setup/lib/brew_helpers.sh"
brew() {
  case "$1" in
    list) return 1 ;;
    install) [[ $# == 2 ]] ;;
    *) return 1 ;;
  esac
}
bh_reset_summary
bh_install_packages --retries 1 first second > /dev/null 2>&1
[[ "${BH_INSTALLED_ITEMS[*]}" == 'first second' && ${#BH_FAILED_ITEMS[@]} == 0 ]] || fail '安装 helper 重试'
pass 'Homebrew helper 批量失败后可逐项重试并记录结果'

printf '\nZsh migration guard passed: %d\n' "$PASS_COUNT"
