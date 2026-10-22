#!/bin/zsh
# filepath: lib/utils.sh
# 通用工具库：日志 fallback、运行时辅助、命令检查、Xcode CLI 安装
# 用法: source "$(dirname "$0")/../lib/utils.sh"

source "${${(%):-%x}:A:h}/resource_lock.sh"

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
  # 与 lib/colors.sh 保持一致：四个日志函数均写 stderr，避免污染 $(...) 捕获值。
  info() { echo "[INFO] $*" >&2; }
  success() { echo "[SUCCESS] $*" >&2; }
  warning() { echo "[WARN] $*" >&2; }
  error() { echo "[ERROR] $*" >&2; }
  log_time_start() { :; }
  log_time_end() { :; }
fi

unset -f _utils_has
source "${${(%):-%x}:A:h}/logging.sh"

# ===== 2. 运行时辅助 =====
prepare_log_file_path() {
  local file_name="$1"
  local log_dir="${MACOS_SCRIPTS_LOG_DIR:-$HOME/Library/Logs/macos-scripts}"
  log_dir="${log_dir:a}"
  local candidate="$log_dir/$file_name"

  if ! mkdir -p "$log_dir" 2>/dev/null || [[ ! -w "$log_dir" ]]; then
    error "日志目录不可用，请检查权限或设置 MACOS_SCRIPTS_LOG_DIR: $log_dir"
    return 1
  fi
  if [[ -e "$candidate" && ( ! -f "$candidate" || ! -w "$candidate" ) ]]; then
    error "日志文件不可写，请检查权限或设置 MACOS_SCRIPTS_LOG_DIR: $candidate"
    return 1
  fi
  printf '%s' "$candidate"
}

get_log_run_mode() {
  # 只识别执行开关，不输出参数；跳过带值选项，避免把标题等值误作开关。
  local mode="实际执行"
  while (( $# > 0 )); do
    case "$1" in
      --dry-run) mode="dry-run"; shift ;;
      --tag|--notes-file|--target|--title|--repo|-d|--domain|-t|--type)
        (( $# >= 2 )) || break
        shift 2
        ;;
      --) break ;;
      *) shift ;;
    esac
  done
  printf '%s' "$mode"
}

write_log_run_header() {
  local mode="${1:-实际执行}"
  local script_name="${2:-${ZSH_ARGZERO:t}}"
  local started_at="${3:-$(date '+%Y-%m-%d %H:%M:%S %z')}"
  printf '\n===== 运行开始 =====\n开始时间: %s\n脚本: %s\n模式: %s\nPID: %s\n====================\n' \
    "$started_at" "$script_name" "$mode" "$$"
}

enable_log_capture() {
  local log_file="$1"
  local mode="${2:-实际执行}"

  if [[ -z "$log_file" ]]; then
    error "未提供日志文件路径，无法启用日志记录"
    return 1
  fi

  # ml_start_capture 先验证普通文件/符号链接，再创建或打开日志。
  ml_start_capture "$log_file" || {
    error "无法初始化日志，请检查权限、日志策略或 MACOS_SCRIPTS_LOG_DIR: $log_file"
    return 1
  }
  write_log_run_header "$mode"
}

# BEGIN MACOS REQUIREMENT
require_supported_macos() {
  local os_version major_version
  if ! command -v sw_vers >/dev/null 2>&1 || ! os_version="$(sw_vers -productVersion)"; then
    error "无法读取 macOS 版本；仅支持 macOS 14 及以上版本，请检查 sw_vers -productVersion。"
    return 1
  fi
  if [[ ! "$os_version" =~ ^[0-9]+([.][0-9]+){0,2}$ ]]; then
    error "无法识别 macOS 版本：${os_version:-空}；请检查 sw_vers -productVersion。"
    return 1
  fi
  major_version="${os_version%%.*}"
  if (( ${#major_version} > 3 )) || (( 10#$major_version < 14 )); then
    error "仅支持 macOS 14 及以上版本，当前版本: $os_version；请升级 macOS 后重新运行。"
    return 1
  fi
}
# END MACOS REQUIREMENT

check_network_reachability() {
  local probe_url="${1:-https://mirrors.ustc.edu.cn}"
  local ping_host="${2:-223.5.5.5}"

  if curl -sIm3 --retry 2 --connect-timeout 30 "$probe_url" > /dev/null 2>&1; then
    return 0
  fi

  ping -c2 "$ping_host" > /dev/null 2>&1
}

# 取命令输出的第一行。
# 用 awk 读完整管道再退出，而不是 `cmd | head -n1`：后者在
# `set -o pipefail` 下，当 writer 因 head 提前退出收到 SIGPIPE(141) 时，
# 整个命令替换会被判为失败。
# BEGIN FIRST LINE
first_line() {
  "$@" 2> /dev/null | awk 'NR == 1 { print }'
}
# END FIRST LINE

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

# ===== 4. Homebrew 定位 =====
resolve_homebrew_bin() {
  if command -v brew > /dev/null 2>&1; then
    command -v brew
    return 0
  fi

  if [[ -x /opt/homebrew/bin/brew ]]; then
    printf '%s' "/opt/homebrew/bin/brew"
    return 0
  fi

  if [[ -x /usr/local/bin/brew ]]; then
    printf '%s' "/usr/local/bin/brew"
    return 0
  fi

  return 1
}

# ===== 5. Xcode CLI 安装 =====
# 参数:
#   --timeout N     最大轮询次数（每次间隔 5 秒），默认 60
#   --no-check      仅验证开发工具路径，跳过 xcrun clang 定位检查
#   --dry-run       仅打印预览
ensure_xcode_cli_installed() {
  local timeout=60
  local check_clang=true
  local dry_run=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --timeout)
        if [[ $# -lt 2 || ! "${2:-}" =~ ^[1-9][0-9]*$ ]]; then
          error "--timeout 需要正整数（每次轮询间隔 5 秒）"
          return 1
        fi
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
      *)
        error "Xcode CLI 检查不支持参数: $1"
        return 1
        ;;
    esac
  done

  require_command xcode-select
  [[ "$check_clang" != true ]] || require_command xcrun
  if xcode-select -p > /dev/null 2>&1; then
    if [[ "$check_clang" == true ]] && ! xcrun --find clang > /dev/null 2>&1; then
      error "开发工具路径已存在，但无法定位 clang。请检查 xcode-select -p 和 xcrun --find clang，修复所选 Xcode/Command Line Tools 后重新运行。"
      return 1
    fi
    success "Xcode 命令行工具已就绪"
    return 0
  fi

  if [[ "$dry_run" == "true" ]]; then
    info "[dry-run] 将执行 xcode-select --install 并等待开发工具就绪（最多 $((timeout * 5)) 秒；默认同时验证 xcrun --find clang）"
    return 0
  fi

  warning "正在安装 Xcode CLI 工具，请在系统窗口中完成安装；--yes 不会自动操作该窗口。"
  if ! xcode-select --install; then
    error "无法启动 Xcode CLI 安装。请手动执行 xcode-select --install，安装完成后重新运行。"
    return 1
  fi

  local wait_count=0
  until xcode-select -p > /dev/null 2>&1 && { [[ "$check_clang" != true ]] || xcrun --find clang > /dev/null 2>&1; }; do
    if (( wait_count >= timeout )); then
      error "Xcode CLI 安装超时（$((timeout * 5)) 秒）。请检查 xcode-select -p 和 xcrun --find clang，完成或修复系统安装后重新运行。"
      return 1
    fi
    info "等待 Xcode CLI 安装完成... (${wait_count}/${timeout}，每次间隔 5 秒)"
    sleep 5 || return 1
    wait_count=$((wait_count + 1))
  done

  success "Xcode 命令行工具已安装"
}
