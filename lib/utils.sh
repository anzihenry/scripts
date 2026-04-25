#!/bin/bash
# 通用工具库：日志 fallback、运行时辅助、命令检查、Xcode CLI 安装
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

# ===== 2. 运行时辅助 =====
prepare_log_file_path() {
  local file_name="$1"
  local fallback_path="${2:-$file_name}"
  local candidate=""
  local candidate_dir=""
  local fallback_dir=""

  if [[ -n "${MACOS_SCRIPTS_LOG_DIR:-}" ]]; then
    candidate="${MACOS_SCRIPTS_LOG_DIR%/}/$file_name"
    candidate_dir="${candidate%/*}"
    if mkdir -p "$candidate_dir" > /dev/null 2>&1 && [[ -w "$candidate_dir" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  fi

  fallback_dir="${fallback_path%/*}"
  [[ "$fallback_dir" == "$fallback_path" ]] && fallback_dir="."
  mkdir -p "$fallback_dir" > /dev/null 2>&1 || true
  printf '%s' "$fallback_path"
}

enable_log_capture() {
  local log_file="$1"

  if [[ -z "$log_file" ]]; then
    warning "未提供日志文件路径，跳过日志重定向"
    return 1
  fi

  if ! : >> "$log_file" 2> /dev/null; then
    warning "日志文件不可写，跳过日志重定向: $log_file"
    return 1
  fi

  exec > >(tee -a "$log_file") 2>&1
}

get_macos_version_code() {
  local os_version="${1:-}"
  local major_version=""
  local minor_version=""

  if [[ -z "$os_version" ]]; then
    os_version="$(sw_vers -productVersion)"
  fi

  major_version="$(printf '%s' "$os_version" | awk -F. '{print $1}')"
  minor_version="$(printf '%s' "$os_version" | awk -F. '{print $2}')"
  printf '%s' $((major_version * 100 + minor_version))
}

require_macos_min_version() {
  local min_version_code="$1"
  local message="${2:-}"
  local os_version
  local current_version_code

  os_version="$(sw_vers -productVersion)"
  current_version_code="$(get_macos_version_code "$os_version")"
  if [[ "$current_version_code" -lt "$min_version_code" ]]; then
    if [[ -n "$message" ]]; then
      log_fatal "$message，当前版本：$os_version"
    fi
    log_fatal "当前 macOS 版本过低：$os_version"
  fi
}

check_network_reachability() {
  local probe_url="${1:-https://mirrors.ustc.edu.cn}"
  local ping_host="${2:-223.5.5.5}"

  if curl -sIm3 --retry 2 --connect-timeout 30 "$probe_url" > /dev/null 2>&1; then
    return 0
  fi

  ping -c2 "$ping_host" > /dev/null 2>&1
}

# ===== 3. 命令检查 =====
require_command() {
  local cmd="$1"
  command -v "$cmd" > /dev/null 2>&1 || {
    log_error "缺少必要命令: $cmd"
    exit 1
  }
}

require_commands() {
  local cmd
  for cmd in "$@"; do
    require_command "$cmd"
  done
}

# ===== 4. Xcode CLI 安装 =====
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
