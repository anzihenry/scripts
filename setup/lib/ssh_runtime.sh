#!/bin/zsh
# filepath: setup/lib/ssh_runtime.sh

test_ssh_connection() {
  local host_alias="$1"
  log_info "测试SSH连接: $host_alias"
  local result code=0
  # 不自动信任未知主机，不提示密码；从已确认的 known_hosts 验证身份。
  result=$(LC_ALL=C ssh -T -o BatchMode=yes -o ConnectTimeout=15 \
    -o ServerAliveInterval=5 -o ServerAliveCountMax=3 \
    -o StrictHostKeyChecking=yes "git@$host_alias" </dev/null 2>&1) || code=$?
  # 普通自建服务正常结束可返回 0；Git forge 禁止交互 shell 时可能返回 1。
  if (( code == 0 )) || { (( code == 1 )) &&
      [[ "$result" == *"You've successfully authenticated, but GitHub does not provide shell access."* || "$result" == *"Welcome to GitLab, "*'!' ]]; }; then
    log_success "SSH连接验证成功"
    return 0
  else
    log_error "远端 SSH 认证未确认（退出码 $code）；本地密钥和配置已保留。"
    log_error "输出: $result"
    if [[ "$result" == *'Host key verification failed'* || "$result" == *'REMOTE HOST IDENTIFICATION HAS CHANGED'* ]]; then
      log_error "请通过可信渠道核对服务端指纹；确认后手动运行 ssh -o StrictHostKeyChecking=ask git@$host_alias，再重试。不要直接删除已记录的主机密钥。"
    elif [[ "$result" == *'Permission denied'* ]]; then
      log_error "请检查公钥是否已上传、私钥是否已解锁并加入 ssh-agent。"
    else
      log_error "请检查网络或服务端策略；自建服务的未知响应需手动验证。"
    fi
    return "$code"
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
