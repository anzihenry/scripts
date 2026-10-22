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
source "$SCRIPT_DIR/lib/ssh_identity.sh"
source "$SCRIPT_DIR/lib/ssh_config.sh"
source "$SCRIPT_DIR/lib/github_keys.sh"
source "$SCRIPT_DIR/lib/ssh_runtime.sh"

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
      (( $# >= 2 )) || { error "--domain 缺少参数"; exit 1; }
      domain="$2"
      shift 2
      ;;
    -t | --type)
      (( $# >= 2 )) || { error "--type 缺少参数"; exit 1; }
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

print_header "SSH密钥管理及Git平台自动配置工具"

mkdir -p "$HOME/.ssh"
SSH_SETUP_LOCK="$HOME/.ssh/.macos-scripts.lock"
if [[ -e "$SSH_SETUP_LOCK" ]]; then
  error "检测到旧版 SSH 锁，请确认旧进程已结束后清理: $SSH_SETUP_LOCK"
  exit 1
fi
resource_lock_acquire "$HOME/.ssh/config" || exit 1
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

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
