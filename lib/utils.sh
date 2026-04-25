#!/bin/bash
# 通用工具库：日志 fallback、命令检查、Xcode CLI 安装
# 自动加载 colors.sh，失败时提供最小日志函数
# 用法: source "$(dirname "$0")/../lib/utils.sh"

# ===== 1. 日志 fallback（colors.sh 不可用时生效）=====
_utils_has() { typeset -f "$1" > /dev/null 2>&1; }

if ! _utils_has log_info; then
  log_info() { echo "[INFO] $*" >&2; }
  log_warn() { echo "[WARN] $*" >&2; }
  log_error() { echo "[ERROR] $*" >&2; }
  log_debug() { [ "${DEBUG:-false}" = "true" ] && echo "[DEBUG] $*" >&2 || true; }
  log_success() { echo "[SUCCESS] $*" >&2; }
  log_fatal() {
    echo "[FATAL] $*" >&2
    exit 1
  }
  print_header() {
    echo
    echo "==== $1 ===="
    echo
  }
  print_step() { echo "[$1/$2] $3"; }
  print_code() { echo "  $1"; }
  highlight() { echo "$*"; }
  info() { echo "[INFO] $*"; }
  success() { echo "[SUCCESS] $*"; }
  warning() { echo "[WARN] $*"; }
  error() { echo "[ERROR] $*" >&2; }
  log_time_start() { :; }
  log_time_end() { :; }
fi

unset -f _utils_has

# ===== 2. 命令检查 =====
require_command() {
  local cmd="$1"
  command -v "$cmd" > /dev/null 2>&1 || {
    log_error "缺少必要命令: $cmd"
    exit 1
  }
}

# ===== 3. Xcode CLI 安装 =====
# 参数:
#   --timeout N     最大轮询次数（每次间隔 5 秒），默认 60
#   --no-check      跳过 /usr/bin/clang 验证
#   --dry-run       仅打印预览
ensure_xcode_cli_installed() {
  local timeout=60
  local check_clang=true
  local dry_run=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --timeout)
        timeout="$2"
        shift 2
        ;;
      --no-check)
        check_clang=false
        shift
        ;;
      --dry-run)
        dry_run=true
        shift
        ;;
      *) shift ;;
    esac
  done

  if xcode-select -p &> /dev/null; then
    success "Xcode 命令行工具已就绪"
    return 0
  fi

  if [[ "$dry_run" == "true" ]]; then
    info "[dry-run] 将执行 xcode-select --install 并等待安装完成"
    return 0
  fi

  warning "正在安装 Xcode CLI 工具... 请在弹出的窗口中完成安装。"
  xcode-select --install

  local wait_count=0
  until xcode-select -p &> /dev/null; do
    info "等待 Xcode CLI 安装完成... (${wait_count}/${timeout})"
    sleep 5
    ((wait_count++))
    [[ $wait_count -gt $timeout ]] && log_fatal "安装超时，请手动执行: xcode-select --install"
  done

  if [[ "$check_clang" == "true" ]]; then
    [[ -f /usr/bin/clang ]] || log_fatal "CLI 工具安装不完整"
  fi

  success "Xcode 命令行工具已安装"
}
