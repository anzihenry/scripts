#!/bin/zsh
# filepath: setup/lib/github_keys.sh

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
  tmpdir="$(mktemp -d)" || return 1
  chmod 700 "$tmpdir" || return 1
  # 兜底清理：中途 Ctrl-C / 其他 set -e 退出也不会把含 token 的目录留在 /tmp。
  _GITHUB_KEY_TMPDIR="$tmpdir"
  trap '_cleanup_github_key_tmpdir' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  trap 'exit 129' HUP
  printf '%s' "$payload" > "$tmpdir/payload.json" || return 1
  {
    echo 'url = "https://api.github.com/user/keys"'
    echo 'header = "Accept: application/vnd.github+json"'
    echo "header = \"Authorization: token $token\""
  } > "$tmpdir/curl.conf" || return 1

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
  local resp http_code body
  local curl_status=0
  resp=$(curl -s --connect-timeout 10 --max-time 120 -w "\n%{http_code}" --config "$tmpdir/curl.conf") || curl_status=$?

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
