#!/bin/zsh
# filepath: setup/lib/ssh_config.sh

update_ssh_config() (
  local domain="$1" usage_type="$2" key_path="$3" host_alias config_file="$HOME/.ssh/config" candidate content
  [[ ! -L "$config_file" || -e "$config_file" ]] || { error "SSH 配置是失效链接"; return 1; }
  config_file="${config_file:A}"
  resource_lock_acquire "$config_file" || return 1
  host_alias="$(generate_host_alias "$domain" "$usage_type")" || return 1
  candidate="$(mktemp "${config_file:h}/.config.XXXXXXXX")" || return 1
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
