#!/bin/zsh
# filepath: setup/git_forge_ssh_setup.sh

set -euo pipefail

if [[ -n "${MACOS_SCRIPTS_CONFIG_DIR:-}" ]]; then
  SSH_BACKUP_DIR="$MACOS_SCRIPTS_CONFIG_DIR/backups"
else
  SSH_BACKUP_DIR=""
fi

# 引入颜色库
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/colors.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/utils.sh"
source "$SCRIPT_DIR/lib/config_writer.sh"

# ========== 工具函数 ==========
sanitize_domain() {
  local domain="$1"
  domain="${domain#*://}"
  domain="${domain#*@}"
  domain="${domain%%:*}"
  domain="${domain%%/*}"
  domain="$(echo "$domain" | tr '[:upper:]' '[:lower:]')"
  if [[ ! "$domain" =~ ^[a-z0-9.-]+\.[a-z]{2,}$ ]]; then
    log_error "无效域名格式: $domain"
    exit 1
  fi
  echo "$domain"
}

ssh_identity_component() {
  local domain="$1" usage_type="$2" legacy="${1%%.*}"
  local owner=""
  if [[ -f "$HOME/.ssh/config" ]]; then
    owner="$(awk -v alias="$legacy-$usage_type" 'tolower($1)=="host"{active=(NF==2 && $2==alias)} active && tolower($1)=="hostname"{print $2;exit}' "$HOME/.ssh/config")"
  fi
  if [[ -n "$owner" && "$owner" != "$domain" ]]; then
    printf '%s' "$domain"
  elif [[ "$domain" == github.com || "$domain" == gitlab.com ]]; then
    printf '%s' "$legacy"
  elif [[ -f "$HOME/.ssh/config" ]] && awk -v alias="$legacy-$usage_type" -v domain="$domain" '
    tolower($1)=="host" { active=(NF==2 && $2==alias) }
    active && tolower($1)=="hostname" && $2==domain { found=1 }
    END { exit !found }
  ' "$HOME/.ssh/config"; then
    printf '%s' "$legacy"
  else
    printf '%s' "$domain"
  fi
}

generate_host_alias() {
  printf '%s-%s' "$(ssh_identity_component "$1" "$2")" "$2"
}

ssh_key_path() {
  printf '%s/.ssh/id_ed25519_%s_%s' "$HOME" "$(ssh_identity_component "$1" "$2")" "$2"
}

get_git_email() {
  local email
  email="$(git config --global user.email 2> /dev/null || true)"
  while [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; do
    # read 在 EOF（非交互 stdin，如 `curl | zsh` 或 </dev/null）时返回非零
    # 且不会修改 email，条件恒真 -> 死循环。必须显式处理失败。
    printf '%s' "$(highlight '请输入有效的Git全局邮箱地址: ')" >&2
    if ! read -r email; then
      log_error "无法读取邮箱输入（stdin 已结束）；请先执行 git config --global user.email <邮箱>"
      return 1
    fi
    if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
      git config --global user.email "$email" || log_error "设置Git邮箱失败"
    fi
  done
  echo "$email"
}

generate_ssh_key() (
  local domain="$1" usage_type="$2" force="$3" key_path pub_key_path derived email staging backup=""
  key_path="$(ssh_key_path "$domain" "$usage_type")" || return 1
  pub_key_path="$key_path.pub"
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh" || return 1
  [[ ! -L "$key_path" && ! -L "$pub_key_path" ]] || { error "密钥路径为符号链接，已保留，请先检查。"; return 1; }
  [[ ( ! -e "$key_path" || -f "$key_path" ) && ( ! -e "$pub_key_path" || -f "$pub_key_path" ) ]] || { error "密钥路径不是普通文件，已保留。"; return 1; }
  if [[ -f "$key_path" && "$force" != true ]]; then
    if [[ ! -e "$pub_key_path" ]]; then
      derived="$(ssh-keygen -y -P '' -f "$key_path")" || { error "无法自动恢复公钥；私钥可能已加密，已保留，请解锁后手动导出公钥: $key_path"; return 1; }
      write_managed_file "$pub_key_path" "$derived" false 644 || return 1
    else
      local private_fingerprint public_fingerprint
      private_fingerprint="$(ssh-keygen -l -f "$key_path" | awk '{print $2}')" || return 1
      public_fingerprint="$(ssh-keygen -l -f "$pub_key_path" | awk '{print $2}')" || return 1
      if [[ -z "$private_fingerprint" || "$private_fingerprint" != "$public_fingerprint" ]]; then
        error "公私钥不匹配，已保留；请检查: $key_path"
        return 1
      fi
    fi
    chmod 600 "$key_path" || return 1
    cat "$pub_key_path"
    return 0
  fi
  [[ ! -e "$pub_key_path" || "$force" == true ]] || { error "仅存在公钥，已保留；请恢复私钥或显式使用 --force。"; return 1; }
  email="$(get_git_email)" || return 1
  staging="$(mktemp -d "$HOME/.ssh/.key.XXXXXXXX")" || return 1
  trap 'rm -rf "$staging"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM HUP
  ssh-keygen -t ed25519 -C "$email [$usage_type@$domain]" -f "$staging/key" -N '' -q || return 1
  if [[ -e "$key_path" || -e "$pub_key_path" ]]; then
    local backup_root="${MACOS_SCRIPTS_CONFIG_DIR:-$HOME/.config/macos-scripts}/backups"
    mkdir -p "$backup_root" || return 1
    backup="$(mktemp -d "$backup_root/ssh-key.XXXXXXXX")" || return 1
    [[ ! -f "$key_path" ]] || cp -p "$key_path" "$backup/private" || return 1
    [[ ! -f "$pub_key_path" ]] || cp -p "$pub_key_path" "$backup/public" || return 1
    warning "已备份被强制替换的密钥，请妥善保管: $backup"
  fi
  if ! { mv -f "$staging/key" "$key_path" && mv -f "$staging/key.pub" "$pub_key_path"; }; then
    if [[ -n "$backup" ]]; then
      [[ ! -f "$backup/private" ]] || cp -p "$backup/private" "$key_path"
      [[ ! -f "$backup/public" ]] || cp -p "$backup/public" "$pub_key_path"
    fi
    return 1
  fi
  chmod 600 "$key_path" && chmod 644 "$pub_key_path" || return 1
  cat "$pub_key_path"
)

update_ssh_config() (
  local domain="$1" usage_type="$2" key_path="$3" host_alias config_file="$HOME/.ssh/config" candidate content
  [[ ! -L "$config_file" || -e "$config_file" ]] || { error "SSH 配置是失效链接"; return 1; }
  config_file="${config_file:A}"
  host_alias="$(generate_host_alias "$domain" "$usage_type")" || return 1
  candidate="$(mktemp "$HOME/.ssh/.config.XXXXXXXX")" || return 1
  trap 'rm -f "$candidate"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM HUP
  if [[ -f "$config_file" ]]; then
    # 已管理的块由公共写入器原位更新；首次迁移旧单 Host 块。
    if grep -Fqx "# >>> SSH $host_alias (managed by macos-scripts) >>>" "$config_file"; then
      cp -p "$config_file" "$candidate" || return 1
    else
      awk -v alias="$host_alias" '
        function flush() { if (pending!="") print pending; pending="" }
        tolower($1)=="host" || tolower($1)=="match" {
          skip=0
          if (tolower($1)=="host") for (i=2;i<=NF;i++) if ($i==alias) { if (NF!=2) {bad=1; exit 1}; skip=1 }
          if (skip) pending=""; else flush()
        }
        skip { next }
        /^# Auto-config:/ { flush(); pending=$0; next }
        { flush(); print }
        END { if (bad) exit 1; flush() }
      ' "$config_file" > "$candidate" || { error "同名 Host 包含多个别名，未修改，请手动拆分。"; return 1; }
    fi
  fi
  content="$(printf 'Host %s\n    HostName %s\n    User git\n    AddKeysToAgent yes\n    UseKeychain yes\n    PubkeyAuthentication yes\n    IdentityFile "%s"' "$host_alias" "$domain" "$key_path")"
  write_managed_block "$candidate" "SSH $host_alias" macos-scripts "$content" || return 1
  /usr/bin/ssh -G -F "$candidate" "$host_alias" >/dev/null 2>&1 || { error "SSH 配置校验失败，原文件未修改。"; return 1; }
  if [[ -f "$config_file" ]] && cmp -s "$candidate" "$config_file"; then
    printf '%s' "$host_alias"
    return 0
  fi
  local backup=""
  if [[ -f "$config_file" ]]; then
    backup="$(mktemp "$HOME/.ssh/.config-backup.XXXXXXXX")" || return 1
    cp -p "$config_file" "$backup" || return 1
  fi
  if ! commit_config_candidate "$config_file" "$candidate" 600; then
    if [[ -n "$backup" ]]; then
      if cp -p "$backup" "$config_file"; then rm -f "$backup"; else error "SSH 配置恢复失败，请保留备份手动恢复: $backup"; fi
    fi
    return 1
  fi
  [[ -z "$backup" ]] || rm -f "$backup"
  printf '%s' "$host_alias"
)

# 幂等清理 upload_github_key 的临时目录（内含 Authorization token）。
# 供 EXIT/INT/TERM/HUP trap 调用，也可在正常路径手动调用。
_cleanup_github_key_tmpdir() {
  if [[ -n "${_GITHUB_KEY_TMPDIR:-}" ]]; then
    rm -rf "$_GITHUB_KEY_TMPDIR"
    _GITHUB_KEY_TMPDIR=""
  fi
  trap - EXIT INT TERM HUP
}

upload_github_key() (
  local pub_key="$1" title="$2" token="$3"
  log_info "上传公钥到GitHub..."

  # 用 python3 生成 JSON，避免手动拼接导致特殊字符破坏 payload
  local payload
  payload="$(python3 -c 'import json, sys; print(json.dumps({"title": sys.argv[1], "key": sys.argv[2]}))' "$title" "$pub_key" 2> /dev/null)" || {
    log_error "生成 JSON payload 失败（需要 python3）"
    return 1
  }

  # token 通过临时 config 文件传给 curl，避免出现在进程列表（ps）中
  local tmpdir
  tmpdir="$(mktemp -d)"
  chmod 700 "$tmpdir"
  # 兜底清理：中途 Ctrl-C / 其他 set -e 退出也不会把含 token 的目录留在 /tmp。
  _GITHUB_KEY_TMPDIR="$tmpdir"
  trap '_cleanup_github_key_tmpdir' EXIT INT TERM HUP
  printf '%s' "$payload" > "$tmpdir/payload.json"
  {
    echo 'url = "https://api.github.com/user/keys"'
    echo 'header = "Accept: application/vnd.github+json"'
    echo "header = \"Authorization: token $token\""
  } > "$tmpdir/curl.conf"

  local lookup lookup_code lookup_body lookup_state lookup_count page=1
  while true; do
    lookup="$(curl -sS --get --data-urlencode per_page=100 --data-urlencode "page=$page" --connect-timeout 10 --max-time 120 -w "\n%{http_code}" --config "$tmpdir/curl.conf")" || return 1
    lookup_code="${lookup##*$'\n'}"
    lookup_body="${lookup%$'\n'*}"
    [[ "$lookup_code" == 200 ]] || { error "无法查询已有 GitHub 公钥（HTTP $lookup_code），未上传。"; return 1; }
    lookup_state=0
    lookup_count="$(printf '%s' "$lookup_body" | python3 -c 'import json,sys
try:
 keys=json.load(sys.stdin)
 desired=" ".join(sys.argv[1].split()[:2])
 print(len(keys))
 sys.exit(0 if any(" ".join(k["key"].split()[:2])==desired for k in keys) else 1)
except Exception:
 sys.exit(2)' "$pub_key")" || lookup_state=$?
    if [[ "$lookup_state" == 0 ]]; then
      success "GitHub 公钥已存在，跳过上传。"
      return 0
    fi
    [[ "$lookup_state" == 1 && "$lookup_count" == <-> ]] || { error "无法解析 GitHub 公钥列表，未上传。"; return 1; }
    (( lookup_count >= 100 )) || break
    page=$((page+1))
  done
  printf 'data = @%s/payload.json\n' "$tmpdir" >> "$tmpdir/curl.conf" || return 1
  local resp http_code
  # 必须用 set +e 捕获 curl 状态：在 set -e 下，裸赋值 `resp=$(curl ...)`
  # 会直接继承 curl 的非零状态并立即退出，导致下面的清理与错误分支成为
  # 死代码，含 Authorization token 的 $tmpdir 残留在 /tmp。
  local curl_status=0
  set +e
  resp=$(curl -s --connect-timeout 10 --max-time 120 -w "\n%{http_code}" --config "$tmpdir/curl.conf")
  curl_status=$?
  set -e

  _cleanup_github_key_tmpdir

  if [[ $curl_status -ne 0 ]]; then
    log_error "GitHub API 请求失败 (curl 状态码 $curl_status)"
    return 1
  fi

  http_code="${resp##*$'\n'}"
  body="${resp%$'\n'*}"
  if [[ "$http_code" == "201" ]]; then
    log_success "公钥已成功上传到GitHub"
    return 0
  elif [[ "$http_code" == "422" && "$body" =~ "key is already in use" ]]; then
    log_warn "公钥已存在于GitHub"
    return 0
  else
    log_error "GitHub API错误 ($http_code): $body"
    return 1
  fi
)

test_ssh_connection() {
  local host_alias="$1"
  log_info "测试SSH连接: $host_alias"
  local result
  result=$(ssh -T -o ConnectTimeout=15 -o StrictHostKeyChecking=no "git@$host_alias" 2>&1 || true)
  if echo "$result" | grep -qi "successfully authenticated"; then
    log_success "SSH连接验证成功"
    return 0
  else
    log_error "SSH连接测试失败"
    log_error "输出: $result"
    return 1
  fi
}

print_usage_instructions() {
  local host_alias="$1"
  print_header "配置完成"
  echo -e "$(highlight '使用方法：')"
  echo -e "1. 克隆新仓库："
  echo -e "   $(highlight "git clone git@$host_alias:username/repo.git")"
  echo -e "2. 更新现有仓库远程地址："
  echo -e "   $(highlight "git remote set-url origin git@$host_alias:username/repo.git")"
  echo -e "3. 验证连接："
  echo -e "   $(highlight "ssh -T git@$host_alias")"
  echo -e "4. 日志文件："
  echo -e "   $(highlight "$SETUP_LOG_FILE")"
  if [[ -n "$SSH_BACKUP_DIR" ]]; then
    echo -e "5. SSH 配置备份目录："
    echo -e "   $(highlight "$SSH_BACKUP_DIR")"
  fi
}

# ========== 主流程 ==========
usage() {
  cat << EOF
用法: $0 [-d domain] [-t personal|work] [--force] [--skip-upload] [--debug]
  -d, --domain      Git平台域名（默认：github.com）
  -t, --type        密钥用途类型（personal|work，默认：personal）
  --force           强制覆盖现有密钥
  --skip-upload     跳过GitHub公钥上传
  --debug           显示调试信息
  -h, --help        显示帮助
EOF
}

# 默认参数
domain="github.com"
usage_type="personal"
force="false"
skip_upload="false"
debug="false"

# 参数解析
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d | --domain)
      domain="$2"
      shift 2
      ;;
    -t | --type)
      usage_type="$2"
      shift 2
      ;;
    --force)
      force="true"
      shift
      ;;
    --skip-upload)
      skip_upload="true"
      shift
      ;;
    --debug)
      debug="true"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      log_error "未知参数: $1"
      usage
      exit 1
      ;;
  esac
done

SETUP_LOG_FILE="$(prepare_log_file_path "setup-git.log")"
enable_log_capture "$SETUP_LOG_FILE"

require_supported_macos || exit 1
[[ -z "$SSH_BACKUP_DIR" ]] || mkdir -p "$SSH_BACKUP_DIR"
if [[ "$debug" == "true" ]]; then
  set -x
fi

[[ "$usage_type" == personal || "$usage_type" == work ]] || { error "--type 仅支持 personal 或 work"; exit 1; }
domain="$(sanitize_domain "$domain")"
host_alias="$(generate_host_alias "$domain" "$usage_type")"

print_header "SSH密钥管理及Git平台自动配置工具"

mkdir -p "$HOME/.ssh"
SSH_SETUP_LOCK="$HOME/.ssh/.macos-scripts.lock"
if ! (umask 077; mkdir "$SSH_SETUP_LOCK") 2>/dev/null; then
  error "另一个 SSH 配置可能正在运行；确认结束后再清理锁: $SSH_SETUP_LOCK"
  exit 1
fi
trap 'rmdir "$SSH_SETUP_LOCK"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

# 1. 生成密钥对
pub_key="$(generate_ssh_key "$domain" "$usage_type" "$force")" || exit $?

# 2. 更新SSH配置
host_alias="$(update_ssh_config "$domain" "$usage_type" "$(ssh_key_path "$domain" "$usage_type")")" || exit $?

# 3. GitHub公钥上传
if [[ "$skip_upload" != "true" && "$domain" == "github.com" ]]; then
  print_header "GitHub公钥上传"
  printf '%s' "$(highlight 'GitHub访问令牌（需admin:public_key权限）: ')" >&2
  [[ "$debug" != true ]] || set +x
  token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
  if [[ -z "$token" ]] && command -v gh >/dev/null 2>&1; then
    token="$(gh auth token 2>/dev/null)" || token=""
  fi
  if [[ -z "$token" ]]; then
    read -r -s token || { error "无法读取令牌；可设置 GH_TOKEN 或使用 --skip-upload。"; exit 1; }
    echo
  fi
  title="$(hostname) [$usage_type] $(date +%Y-%m-%d)"
  upload_state=0
  upload_github_key "$pub_key" "$title" "$token" || upload_state=$?
  unset token
  [[ "$debug" != true ]] || set -x
  [[ "$upload_state" == 0 ]] || { error "公钥上传未完成，已有密钥和 SSH 配置保留，可安全重试。"; exit "$upload_state"; }
fi

# 4. 连接测试
print_header "SSH连接测试"
test_ssh_connection "$host_alias" || {
  log_error "请检查："
  log_error "1. 公钥是否已添加到Git平台"
  log_error "2. 防火墙或网络设置"
  log_error "3. SSH配置是否正确"
  exit 1
}

# 5. 输出使用说明
print_usage_instructions "$host_alias"
