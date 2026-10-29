#!/bin/zsh
# filepath: tests/idempotence_guard.sh
# 真实临时文件、临时密钥和本地 Git 仓库；外部网络/磁盘操作均用桩。
set -euo pipefail
ROOT="${0:A:h:h}"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/macos-scripts-idempotence.XXXXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home" MACOS_SCRIPTS_CONFIG_DIR="$SANDBOX/config" MACOS_SCRIPTS_LOG_DIR="$SANDBOX/logs"
mkdir -p "$HOME" "$SANDBOX/bin"
source "$ROOT/lib/colors.sh"
source "$ROOT/lib/utils.sh"
source "$ROOT/lib/config_writer.sh"
PASS_COUNT=0
pass() { print "[PASS] $1"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { print -u2 "[FAIL] $1"; exit 1; }

# 配置稳定、位置不变、标记损坏拒绝、符号链接保留。
config="$HOME/.zshrc"
printf '# user head\n# >>> Demo (managed by test) >>>\nOLD=1\n# <<< Demo (managed by test) <<<\n# user tail\n' > "$config"
write_managed_block "$config" Demo test 'NEW=1'
cp -p "$config" "$SANDBOX/first"
write_managed_block "$config" Demo test 'NEW=1'
cmp -s "$config" "$SANDBOX/first" || fail '相同配置重复执行必须逐字节不变'
[[ "$(tail -n1 "$config")" == '# user tail' ]] || fail '配置块不应移动到文件末尾'
pass '配置块原位更新，重复执行逐字节不变'
printf '# >>> Demo (managed by test) >>>\n' >> "$config"
cp "$config" "$SANDBOX/malformed"
if write_managed_block "$config" Demo test 'BAD=1' 2>/dev/null; then fail '重复标记应拒绝'; fi
cmp -s "$config" "$SANDBOX/malformed" || fail '损坏配置应保持原样'
pass '损坏标记不吞掉用户配置'
cp "$SANDBOX/first" "$SANDBOX/linked-rc"
rm "$config"
ln -s "$SANDBOX/linked-rc" "$config"
write_managed_block "$config" Demo test 'NEW=1'
[[ -L "$config" ]] || fail '保留符号链接'
pass '配置写入保留符号链接'
printf '[global]\ntimeout = 42\nindex-url = old\n[install]\nuser = true\n' > "$HOME/pip.conf"
set_ini_value "$HOME/pip.conf" global index-url https://example.invalid/simple
cp "$HOME/pip.conf" "$SANDBOX/pip-first"
set_ini_value "$HOME/pip.conf" global index-url https://example.invalid/simple
cmp -s "$HOME/pip.conf" "$SANDBOX/pip-first" || fail 'INI 重复更新不应变化'
grep -q 'timeout = 42' "$HOME/pip.conf" && grep -q 'user = true' "$HOME/pip.conf" || fail 'INI 应保留用户选项'
pass 'pip 合并只改变目标键且无变化不写入'

source "$ROOT/setup/lib/shell_setup.sh"
rm "$config"
printf 'export USER_KEEP=1\nZSH_THEME="custom"\n' > "$config"
update_zsh_config
cp "$config" "$SANDBOX/shell-first"
update_zsh_config
cmp -s "$config" "$SANDBOX/shell-first" || fail 'Shell 配置重复变化'
grep -q 'export USER_KEEP=1' "$config" && grep -q '^ZSH_THEME="custom"' "$config" || fail '保留用户 Shell 配置'
pass '终端配置保留用户和 Homebrew 块，重复不变'
# 本地仓库验证可用资源跳过，失败克隆不会污染正式位置。
command git init -q "$SANDBOX/origin"
printf '# fake framework\n' > "$SANDBOX/origin/oh-my-zsh.sh"
command git -C "$SANDBOX/origin" add .
command git -C "$SANDBOX/origin" -c user.name=Test -c user.email=test@example.invalid -c commit.gpgsign=false commit -qm fixture
ensure_shell_repository "$SANDBOX/checkout" "$SANDBOX/missing" "$SANDBOX/origin" oh-my-zsh.sh >/dev/null 2>&1
printf 'local change\n' >> "$SANDBOX/checkout/oh-my-zsh.sh"
ensure_shell_repository "$SANDBOX/checkout" "$SANDBOX/missing" "$SANDBOX/missing" oh-my-zsh.sh
[[ "$(tail -n1 "$SANDBOX/checkout/oh-my-zsh.sh")" == 'local change' ]] || fail '已有健康仓库不得删除'
if ensure_shell_repository "$SANDBOX/failed-checkout" "$SANDBOX/missing" "$SANDBOX/missing" oh-my-zsh.sh >/dev/null 2>&1; then fail '克隆失败应失败'; fi
[[ ! -e "$SANDBOX/failed-checkout" ]] || fail '失败不留下半个仓库'
pass '仓库失败不污染目标，已有仓库及本地改动保留'
cat > "$SANDBOX/bin/curl" <<'SHIM'
#!/bin/zsh
while (( $# > 0 )); do
 if [[ "$1" == -o ]]; then destination="$2"; shift 2; else shift; fi
done
if [[ "${FONT_FAIL:-false}" == true ]]; then printf partial > "$destination"; exit 1; fi
printf '\000\001\000\000\000\001\000\000\000\000\000\000head\000\000\000\000\000\000\000\034\000\000\000\004data' > "$destination"
SHIM
chmod +x "$SANDBOX/bin/curl"
export PATH="$SANDBOX/bin:$PATH"
export FONT_FAIL=true
if install_one_font "$HOME/font.ttf" fake; then fail '字体下载失败应失败'; fi
[[ ! -e "$HOME/font.ttf" ]] || fail '字体失败不能写正式路径'
export FONT_FAIL=false
install_one_font "$HOME/font.ttf" fake
export FONT_FAIL=true
install_one_font "$HOME/font.ttf" fake
pass '字体原子下载且健康字体跳过网络'
unset FONT_FAIL

# 通过独立进程完整执行 SSH，验证第二次不读取 stdin、不换密钥、不改配置。
cat > "$SANDBOX/bin/git" <<'SHIM'
#!/bin/zsh
printf 'test@example.invalid\n'
SHIM
cat > "$SANDBOX/bin/ssh" <<'SHIM'
#!/bin/zsh
printf 'successfully authenticated\n'
SHIM
chmod +x "$SANDBOX/bin/git" "$SANDBOX/bin/ssh"
/bin/zsh "$ROOT/setup/git_forge_ssh_setup.sh" --skip-upload </dev/null > "$SANDBOX/ssh-output" 2>&1
cp "$HOME/.ssh/config" "$SANDBOX/ssh-first"
cp "$HOME/.ssh/id_ed25519_github_personal" "$SANDBOX/key-first"
/bin/zsh "$ROOT/setup/git_forge_ssh_setup.sh" --skip-upload </dev/null > "$SANDBOX/ssh-output" 2>&1
cmp -s "$HOME/.ssh/config" "$SANDBOX/ssh-first" && cmp -s "$HOME/.ssh/id_ed25519_github_personal" "$SANDBOX/key-first" || fail 'SSH 重复应保持配置和私钥'
rm "$HOME/.ssh/id_ed25519_github_personal.pub"
/bin/zsh "$ROOT/setup/git_forge_ssh_setup.sh" --skip-upload </dev/null > "$SANDBOX/ssh-output" 2>&1
[[ -s "$HOME/.ssh/id_ed25519_github_personal.pub" ]] && cmp -s "$HOME/.ssh/id_ed25519_github_personal" "$SANDBOX/key-first" || fail '应从私钥恢复公钥'
pass 'SSH 无交互复用私钥和配置，并恢复缺失公钥'
mkdir -p "$SANDBOX/dot files"
mv "$HOME/.ssh/config" "$SANDBOX/dot files/ssh config"
ln -s "$SANDBOX/dot files/ssh config" "$HOME/.ssh/config"
/bin/zsh "$ROOT/setup/git_forge_ssh_setup.sh" --domain github.example.com --skip-upload </dev/null > "$SANDBOX/ssh-output" 2>&1
[[ -L "$HOME/.ssh/config" ]] || fail 'SSH 配置链接必须保留'
cp "$HOME/.ssh/config" "$SANDBOX/linked-ssh-first"
/bin/zsh "$ROOT/setup/git_forge_ssh_setup.sh" --domain github.example.com --skip-upload </dev/null > "$SANDBOX/ssh-output" 2>&1
cmp -s "$HOME/.ssh/config" "$SANDBOX/linked-ssh-first" || fail '链接配置重复执行必须不变'
pass 'SSH 跨目录符号链接和带空格路径可更新且重复稳定'
/bin/zsh "$ROOT/setup/git_forge_ssh_setup.sh" --domain gitlab.company.com --skip-upload </dev/null > "$SANDBOX/ssh-output" 2>&1
/bin/zsh "$ROOT/setup/git_forge_ssh_setup.sh" --domain gitlab.other.com --skip-upload </dev/null > "$SANDBOX/ssh-output" 2>&1
[[ -f "$HOME/.ssh/id_ed25519_gitlab.company.com_personal" && -f "$HOME/.ssh/id_ed25519_gitlab.other.com_personal" ]] || fail '完整域名隔离密钥'
pass '不同 Git 域名不共用身份'
ssh_config_target="${HOME}/.ssh/config"
sed -i '' 's/HostName github.com$/HostName github.company.com/' "${ssh_config_target:A}"
/bin/zsh "$ROOT/setup/git_forge_ssh_setup.sh" --skip-upload </dev/null > "$SANDBOX/ssh-output" 2>&1
[[ -s "$HOME/.ssh/id_ed25519_github.com_personal" ]] || fail '旧私有域名别名不应与公网身份冲突'
cmp -s "$HOME/.ssh/id_ed25519_github_personal" "$SANDBOX/key-first" || fail '旧私有域名密钥不得覆盖'
pass '旧命名冲突时保留旧身份并使用完整域名'



# 已上传的 GitHub 公钥先查询复用，查询失败不继续上传且释放本地锁。
cat > "$SANDBOX/bin/curl" <<'SHIM'
#!/bin/zsh
while (( $# > 0 )); do
  if [[ "$1" == --config ]]; then config="$2"; shift 2; else shift; fi
done
if [[ "${TEST_UPLOAD_FAILURE:-false}" == true ]]; then printf 'failure\n500'; exit 0; fi
if grep -q '^data =' "$config"; then
  : > "$TEST_UPLOAD_MARKER"
  printf '\n201'
else
  python3 -c 'import json,sys; print(json.dumps([{"key":open(sys.argv[1]).read().strip()}]))' "$TEST_UPLOAD_PUBLIC"
  printf '\n200'
fi
SHIM
chmod +x "$SANDBOX/bin/curl"
export TEST_UPLOAD_MARKER="$SANDBOX/upload-post" TEST_UPLOAD_PUBLIC="$HOME/.ssh/id_ed25519_github.com_personal.pub"
GH_TOKEN=fake /bin/zsh "$ROOT/setup/git_forge_ssh_setup.sh" </dev/null > "$SANDBOX/upload-output" 2>&1
[[ ! -e "$TEST_UPLOAD_MARKER" ]] || fail '已有 GitHub 公钥不应再次 POST'
if GH_TOKEN=fake TEST_UPLOAD_FAILURE=true /bin/zsh "$ROOT/setup/git_forge_ssh_setup.sh" </dev/null > "$SANDBOX/upload-output" 2>&1; then fail '查询上传状态失败应返回非零'; fi
[[ ! -e "$TEST_UPLOAD_MARKER" && ! -e "$HOME/.ssh/.macos-scripts.lock" ]] || fail '查询失败不上传并释放锁'
pass 'GitHub 公钥已存在不上传，查询失败可安全重试'
mkdir "$MACOS_SCRIPTS_CONFIG_DIR/.setup-shell.lock"
if /bin/zsh "$ROOT/setup/ohmyzsh-setup.sh" > "$SANDBOX/shell-lock-output" 2>&1; then fail '已有终端配置锁时不能执行'; fi
[[ -d "$MACOS_SCRIPTS_CONFIG_DIR/.setup-shell.lock" ]] || fail '不能清理其他进程的锁'
rmdir "$MACOS_SCRIPTS_CONFIG_DIR/.setup-shell.lock"
pass '终端初始化拒绝并发且不删除其他进程的锁'

# 加密的已有密钥用公开指纹验证，无需解密或覆盖。
(
  export HOME="$SANDBOX/encrypted-home"
  mkdir -p "$HOME/.ssh"
  /usr/bin/ssh-keygen -t ed25519 -N test-passphrase -f "$HOME/.ssh/id_ed25519_github_personal" -q
  cp "$HOME/.ssh/id_ed25519_github_personal" "$SANDBOX/encrypted-first"
  /bin/zsh "$ROOT/setup/git_forge_ssh_setup.sh" --skip-upload </dev/null > "$SANDBOX/encrypted-output" 2>&1
  cmp -s "$HOME/.ssh/id_ed25519_github_personal" "$SANDBOX/encrypted-first"
) || fail '已有加密密钥应无交互复用'
pass '已有加密密钥通过公私钥指纹复用'
# 语言配置使用命令桩，重复运行不升级 Node/npm、不覆盖 pip 自定义项。
(
  export HOME="$SANDBOX/language-home" LANG_PREFIX="$SANDBOX/language-prefix"
  mkdir -p "$HOME/.pip" "$LANG_PREFIX/opt/nvm" "$LANG_PREFIX/bin"
  cat > "$LANG_PREFIX/opt/nvm/nvm.sh" <<'NVM'
nvm() {
  if [[ "$1" == install ]]; then print install >> "$LANG_PREFIX/actions"; fi
  return 0
}
NVM
  cat > "$LANG_PREFIX/bin/gem" <<'GEM'
#!/bin/zsh
if [[ "$*" == 'sources --list' ]]; then print https://mirrors.ustc.edu.cn/rubygems/; else print "$*" >> "$LANG_PREFIX/actions"; fi
GEM
  chmod +x "$LANG_PREFIX/bin/gem"
  brew() { case "$1" in --prefix) print "$LANG_PREFIX" ;; list) return 0 ;; *) print "$*" >> "$LANG_PREFIX/actions" ;; esac; }
  npm() { if [[ "$*" == 'config get registry' ]]; then print https://registry.npmmirror.com; else print "$*" >> "$LANG_PREFIX/actions"; fi; }
  printf '[global]\ntimeout = 42\n' > "$HOME/.pip/pip.conf"
  source "$ROOT/setup/lib/setup_lang_env.sh"
  for iteration in 1 2; do
    install_node >/dev/null
    install_python >/dev/null
    install_ruby >/dev/null
    install_go >/dev/null
    config_android_and_java >/dev/null
    if [[ "$iteration" == 1 ]]; then cp "$HOME/.zshrc" "$SANDBOX/language-first"; fi
  done
  cmp -s "$HOME/.zshrc" "$SANDBOX/language-first" || exit 1
  grep -q 'timeout = 42' "$HOME/.pip/pip.conf" || exit 1
  [[ ! -e "$LANG_PREFIX/actions" ]] || exit 1
) || fail '语言环境重复执行不应升级已有 Node/npm 或重复修改镜像'
pass '语言初始化不隐式升级，配置与镜像状态收敛'
(
  source "$ROOT/setup/lib/homebrew_config.sh"
  brew() { if [[ "$1" == --prefix ]]; then print /example; else print '''export PATH="/example/bin:$PATH"'''; fi; }
  activate_homebrew_environment brew
  first="$PATH"
  activate_homebrew_environment brew
  [[ "$first" == "$PATH" ]]
) || fail '重复激活 Homebrew 不应重复 PATH'
pass '重复激活环境不会累加 PATH'

source "$ROOT/maintain/lib/macos_installer_utils.sh"
installer_version_matches 14.6.1 14.6 || fail '允许版本组件前缀'
if installer_version_matches 14.6.10 14.6.1; then fail '不允许不完整组件匹配'; fi
pass '安装器版本使用组件边界'
CREATE_VOLUME="$SANDBOX/volume"
CREATE_APP_VERSION=20.1
CREATE_SOURCE_ID=source-identity
mkdir -p "$CREATE_VOLUME/Install macOS Test.app" "$MACOS_SCRIPTS_CONFIG_DIR/installer-state"
mkdir -p "$CREATE_VOLUME/Install macOS Test.app/Contents/SharedSupport"
printf Info > "$CREATE_VOLUME/Install macOS Test.app/Contents/Info.plist"
printf payload > "$CREATE_VOLUME/Install macOS Test.app/Contents/SharedSupport/SharedSupport.dmg"
CREATE_SOURCE_ID="$(installer_source_identity "$CREATE_VOLUME/Install macOS Test.app")"
installer_volume_value() { print UUID-123; }
get_installer_short_ver() { print 20.1; }
printf '%s\n' "$CREATE_SOURCE_ID" > "$MACOS_SCRIPTS_CONFIG_DIR/installer-state/UUID-123"
if volume_creation_current; then fail '只有 app 和完成记录不能证明引导文件完好'; fi
: > "$CREATE_VOLUME/.IAPhysicalMedia"
volume_creation_current || fail '完成记录、UUID、版本与引导标记一致时应跳过'
printf tampered > "$CREATE_VOLUME/Install macOS Test.app/Contents/SharedSupport/SharedSupport.dmg"
if volume_creation_current; then fail '载荷变化后不能凭旧完成记录跳过'; fi
printf payload > "$CREATE_VOLUME/Install macOS Test.app/Contents/SharedSupport/SharedSupport.dmg"
printf changed > "$MACOS_SCRIPTS_CONFIG_DIR/installer-state/UUID-123"
if volume_creation_current; then fail '不同安装器身份不能跳过'; fi
pass 'U 盘重复执行校验 UUID、安装器身份和引导文件'

# 安装器元数据只读挂载、解析真实 OSVersion，并保证正常/失败都卸载。
(
  app="$SANDBOX/metadata-app"
  mkdir -p "$app/Contents/SharedSupport"
  printf fake > "$app/Contents/SharedSupport/SharedSupport.dmg"
  export TMPDIR="$SANDBOX/metadata-tmp"
  mkdir -p "$TMPDIR"
  hdiutil() {
    local action="$1" mount=""
    shift
    if [[ "$action" == attach ]]; then
      while (( $# > 0 )); do
        if [[ "$1" == -mountpoint ]]; then mount="$2"; shift 2; else shift; fi
      done
      mkdir -p "$mount/com_apple_MobileAsset_MacSoftwareUpdate"
      cat > "$mount/com_apple_MobileAsset_MacSoftwareUpdate/com_apple_MobileAsset_MacSoftwareUpdate.xml" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>Assets</key><array><dict><key>OSVersion</key><string>14.6.1</string></dict></array></dict></plist>
PLIST
    elif [[ "$action" == detach ]]; then
      rm "$1/com_apple_MobileAsset_MacSoftwareUpdate/com_apple_MobileAsset_MacSoftwareUpdate.xml"
      rmdir "$1/com_apple_MobileAsset_MacSoftwareUpdate"
    fi
  }
  [[ "$(get_installer_os_version "$app")" == 14.6.1 ]] || exit 1
  [[ -z "$(print -l "$TMPDIR"/*(N))" ]] || exit 1
) || fail '系统版本应取自载荷元数据，并卸载临时映像'
pass '只读解析安装器系统版本并清理挂载点'

(
  source "$ROOT/maintain/lib/brew_updater_args.sh"
  source "$ROOT/maintain/lib/brew_updater_casks.sh"
  source "$ROOT/maintain/lib/brew_updater_runtime.sh"
  initialize_brew_updater_context
  ERROR_LOG="$SANDBOX/maintenance-errors"
  get_outdated_casks() { return 1; }
  run_cask_upgrades >/dev/null 2>&1
  result=0
  print_summary >/dev/null 2>&1 || result=$?
  [[ "$result" == 1 ]]
) || fail 'Cask 检测失败不能返回成功'
pass '维护检测失败不会伪报成功'
(
  app="$SANDBOX/incomplete-app"
  mkdir -p "$app/Contents/SharedSupport" "$app/Contents/Resources"
  printf info > "$app/Contents/Info.plist"
  printf data > "$app/Contents/SharedSupport/SharedSupport.dmg"
  printf '#!/bin/zsh\n' > "$app/Contents/Resources/createinstallmedia"
  chmod +x "$app/Contents/Resources/createinstallmedia"
  hdiutil() { [[ "${IMAGE_BROKEN:-false}" == false ]]; }
  installer_is_complete "$app" || exit 1
  IMAGE_BROKEN=true
  if installer_is_complete "$app"; then exit 1; fi
) || fail '损坏的载荷不能视为完整安装器'
pass '安装器完整性检查拒绝损坏镜像'
print "\nIdempotence guard passed: $PASS_COUNT"
