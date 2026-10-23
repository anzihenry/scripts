#!/bin/zsh
# filepath: setup/lib/ssh_identity.sh

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
