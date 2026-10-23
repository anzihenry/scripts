#!/bin/zsh
# filepath: setup/lib/ssh_runtime.sh

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
