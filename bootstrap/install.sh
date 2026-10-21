#!/bin/zsh
# filepath: bootstrap/install.sh

set -e
set -u
set -o pipefail

SCRIPT_PATH="${0:A}"
SCRIPT_DIR="${SCRIPT_PATH:h}"
REPO_ROOT="${SCRIPT_DIR:h}"

REPO_SLUG="anzihenry/scripts"
TAP_NAME="anzihenry/scripts"
DEFAULT_TAP_REMOTE_URL="https://github.com/$REPO_SLUG"
TAP_REMOTE_URL="${TAP_REMOTE_URL:-$DEFAULT_TAP_REMOTE_URL}"
FORMULA_NAME="macos-scripts"
HOMEBREW_DOWNLOAD_CONNECT_TIMEOUT=10
HOMEBREW_DOWNLOAD_MAX_TIME=120

# 版本号以仓库根目录的 VERSION 文件为唯一权威来源（本地联调时生效）；
# 通过 curl 管道执行时该文件不存在，回退到环境变量/内置默认值。
if [[ -r "$REPO_ROOT/VERSION" ]]; then
  FORMULA_STABLE_VERSION="${FORMULA_STABLE_VERSION:-$(<"$REPO_ROOT/VERSION")}"
else
  FORMULA_STABLE_VERSION="${FORMULA_STABLE_VERSION:-0.5.0}"
fi
BOOTSTRAP_RELEASE_TAG="${BOOTSTRAP_RELEASE_TAG:-v${FORMULA_STABLE_VERSION}}"

usage() {
  cat <<EOF
用法:
  bootstrap/install.sh [选项]

说明:
  请以普通用户运行；root（包括 sudo 启动）不可执行或预演，仅可查看帮助。
  独立完成首次 bootstrap：安装 Homebrew、tap 安装 macos-scripts，
  并默认执行 'macos-scripts setup brew configure' 进入统一 CLI 链路。
  默认安装 stable 版本；如需开发版，可后续手动执行 brew install --HEAD。
  已安装 macos-scripts 时跳过安装和升级，继续执行配置。
  默认从 /dev/tty 读取确认；无交互终端时请使用 --yes。
  实际安装使用运行锁防止并发；--help 和 --dry-run 不占锁。
  如需本地联调，可通过环境变量 TAP_REMOTE_URL 覆盖 tap 源。

选项:
  --dry-run         仅打印将执行的步骤，不实际执行
  --yes             跳过脚本和 Homebrew 安装确认（NONINTERACTIVE=1）
                    Xcode 系统窗口仍需手动完成；Homebrew 权限不足时中止
  --skip-configure  安装完成后不自动执行 'macos-scripts setup brew configure'
  -h, --help        显示帮助

示例:
  zsh bootstrap/install.sh
  zsh bootstrap/install.sh --dry-run
  curl -fsSL https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_RELEASE_TAG}/bootstrap/install.sh | zsh
EOF
}

YES="false"
DRY_RUN="false"
SKIP_CONFIGURE="false"

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN="true"
        shift
        ;;
      --yes|-y)
        YES="true"
        shift
        ;;
      --skip-configure)
        SKIP_CONFIGURE="true"
        shift
        ;;
      -h|--help|help)
        usage
        exit 0
        ;;
      *)
        printf '未知参数: %s\n' "$1" >&2
        echo
        usage
        exit 1
        ;;
    esac
  done
}

# 纯查询和无效参数在日志初始化前处理。
parse_args "$@"

# 在日志、目录和运行锁初始化前拒绝 root；仅帮助允许无副作用地返回。
# 使用 Zsh 的有效用户 ID，避免依赖可被 PATH 替换的 id 命令。
if (( EUID == 0 )); then
  printf '不能以 root 身份运行 bootstrap（包括 --dry-run）。请退出 root 会话，或去掉 sudo 后以普通用户重新运行原命令；安装步骤需要的管理员权限由对应安装器处理。\n' >&2
  exit 1
fi

MACOS_SCRIPTS_LOG_DIR="${MACOS_SCRIPTS_LOG_DIR:-$HOME/Library/Logs/macos-scripts}"
MACOS_SCRIPTS_LOG_DIR="${MACOS_SCRIPTS_LOG_DIR:a}"
export MACOS_SCRIPTS_LOG_DIR
BOOTSTRAP_LOG_FILE="$MACOS_SCRIPTS_LOG_DIR/bootstrap.log"
if ! mkdir -p "$MACOS_SCRIPTS_LOG_DIR"; then
  printf '日志目录或文件不可写，请检查权限或设置 MACOS_SCRIPTS_LOG_DIR: %s\n' "$BOOTSTRAP_LOG_FILE" >&2
  exit 1
fi

if [[ -r "$REPO_ROOT/lib/logging.sh" ]]; then
  source "$REPO_ROOT/lib/logging.sh"
else
# BEGIN STANDALONE LOGGING
# 有界日志：按字节轮转，归档清理；系统文件锁协调多个写入进程。

ml_log_policy() {
  ML_MAX_BYTES="${MACOS_SCRIPTS_LOG_MAX_BYTES:-5242880}"
  ML_BACKUPS="${MACOS_SCRIPTS_LOG_BACKUPS:-5}"
  ML_RETENTION_DAYS="${MACOS_SCRIPTS_LOG_RETENTION_DAYS:-30}"
  local value
  for value in "$ML_MAX_BYTES" "$ML_BACKUPS" "$ML_RETENTION_DAYS"; do
    if [[ "$value" != <-> || ${#value} -gt 10 ]] || (( value < 1 )); then
      printf '日志轮转参数必须为正整数。\n' >&2
      return 1
    fi
  done
  if (( ML_MAX_BYTES > 1073741824 || ML_BACKUPS > 100 || ML_RETENTION_DAYS > 3650 )); then
    printf '日志轮转上限：单文件 1 GiB、100 份归档、3650 天。\n' >&2
    return 1
  fi
}

ml_trim_log() {
  local target="$1" size temp_file
  size="$(stat -f '%z' "$target")" || return 1
  (( size > ML_MAX_BYTES )) || return 0
  temp_file="$(mktemp "${target}.trim.XXXXXXXX")" || return 1
  if ! tail -c "$ML_MAX_BYTES" "$target" > "$temp_file" || ! mv -f "$temp_file" "$target"; then
    rm -f "$temp_file"
    return 1
  fi
}

ml_rotate_log() {
  local log_file="$1" index
  rm -f "$log_file.$ML_BACKUPS" || return 1
  for ((index = ML_BACKUPS - 1; index >= 1; index--)); do
    [[ ! -f "$log_file.$index" ]] || mv -f "$log_file.$index" "$log_file.$((index + 1))" || return 1
  done
  [[ ! -f "$log_file" ]] || mv -f "$log_file" "$log_file.1" || return 1
  : > "$log_file"
}

ml_locked_write() (
  emulate -L zsh
  setopt no_multibyte
  umask 077
  local log_file="$1" data="$2" maintain="${3:-false}"
  local lock_file="$log_file.lock" lock_fd candidate suffix modified cutoff size room part
  zmodload zsh/system || return 1
  # 不跟随符号链接，不处理归档命名之外的文件。
  for candidate in "$log_file" "$lock_file" "$log_file".*(N); do
    [[ "$candidate" == "$log_file" || "$candidate" == "$lock_file" || "${candidate##*.}" == <-> ]] || continue
    if [[ -L "$candidate" || ( -e "$candidate" && ! -f "$candidate" ) ]]; then
      printf '日志路径不是普通文件，拒绝轮转: %s\n' "$candidate" >&2
      return 1
    fi
  done
  : >> "$lock_file" || return 1
  # 内核锁随进程/描述符退出释放，不依赖清理 PID 文件。
  zsystem flock -t 5 -f lock_fd "$lock_file" || return 1
  if [[ "$maintain" == true ]]; then
    cutoff=$(( $(date +%s) - ML_RETENTION_DAYS * 86400 ))
    for candidate in "$log_file".*(N); do
      suffix="${candidate##*.}"
      [[ "$suffix" == <-> && ${#suffix} -le 9 ]] || continue
      modified="$(stat -f '%m' "$candidate")" || return 1
      if (( suffix < 1 || suffix > ML_BACKUPS || modified < cutoff )); then
        rm -f "$candidate" || return 1
      else
        ml_trim_log "$candidate" || return 1
      fi
    done
  fi
  : >> "$log_file" || return 1
  size="$(stat -f '%z' "$log_file")" || return 1
  if (( size > ML_MAX_BYTES )); then
    # 接管旧的大文件时只保留末尾预算内内容，再作为最近归档保留。
    ml_trim_log "$log_file" || return 1
    ml_rotate_log "$log_file" || return 1
    size=0
  fi
  while [[ -n "$data" ]]; do
    if (( size >= ML_MAX_BYTES )); then
      ml_rotate_log "$log_file" || return 1
      size=0
    fi
    room=$(( ML_MAX_BYTES - size ))
    part="${data[1,room]}"
    printf '%s' "$part" >> "$log_file" || return 1
    size=$(( size + ${#part} ))
    data="${data[${#part}+1,-1]}"
  done
)

ml_append_log() {
  ml_log_policy || return 1
  ml_locked_write "$1" "$2" true
}

ml_stream_log() {
  emulate -L zsh
  setopt no_multibyte localtraps
  # 让父进程先完成中断摘要并关闭输出；记录器排空管道后再退出。
  trap '' INT TERM HUP
  zmodload zsh/system || return 1
  local log_file="$1" chunk="" failed=false
  while sysread -s 65536 chunk; do
    printf '%s' "$chunk"
    if [[ "$failed" == false ]] && ! ml_locked_write "$log_file" "$chunk" false; then
      printf '日志写入或轮转失败，终端输出继续保留，请检查: %s\n' "$log_file" >&2
      failed=true
    fi
  done
  [[ "$failed" == false ]]
}

ml_start_capture() {
  ml_log_policy || return 1
  ml_locked_write "$1" '' true || return 1
  # Zsh 的进程替换不保证提供 $!；使用私有 FIFO 启动可 wait 的子进程。
  # FIFO 在双方打开后立即删除，正常运行和中断均不留下临时文件。
  local stream_dir stream_fifo
  stream_dir="$(mktemp -d "${TMPDIR:-/tmp}/macos-scripts-log.XXXXXXXX")" || return 1
  stream_fifo="$stream_dir/stream"
  if ! (umask 077; mkfifo "$stream_fifo"); then
    rmdir "$stream_dir"
    return 1
  fi
  exec {ML_CAPTURE_STDOUT}>&1 {ML_CAPTURE_STDERR}>&2
  setopt localoptions no_bg_nice
  ml_stream_log "$1" < "$stream_fifo" >&$ML_CAPTURE_STDOUT 2>&$ML_CAPTURE_STDERR &
  ML_CAPTURE_PID=$!
  exec > "$stream_fifo" 2>&1
  ML_CAPTURE_ACTIVE=true
  ML_CAPTURE_DIR="$stream_dir"
  if rm -f "$stream_fifo" && rmdir "$stream_dir"; then
    ML_CAPTURE_DIR=""
  else
    printf '日志通道临时目录清理失败，退出时重试: %s\n' "$stream_dir" >&2
  fi
  # 与业务 EXIT trap 分离；显式退出/正常退出时排空记录器，保留原退出码。
  typeset -ga zshexit_functions
  (( ${zshexit_functions[(Ie)ml_finish_capture]} )) || zshexit_functions+=(ml_finish_capture)
}

ml_finish_capture() {
  local exit_code=$?
  [[ "${ML_CAPTURE_ACTIVE:-false}" == true ]] || return "$exit_code"
  ML_CAPTURE_ACTIVE=false
  exec 1>&$ML_CAPTURE_STDOUT 2>&$ML_CAPTURE_STDERR
  exec {ML_CAPTURE_STDOUT}>&- {ML_CAPTURE_STDERR}>&-
  wait "$ML_CAPTURE_PID" || :
  if [[ -n "${ML_CAPTURE_DIR:-}" ]]; then
    if ! { rm -f "$ML_CAPTURE_DIR/stream" && rmdir "$ML_CAPTURE_DIR"; }; then
      printf '日志通道临时目录未能清理，请检查: %s\n' "$ML_CAPTURE_DIR" >&2
    fi
  fi
  return "$exit_code"
}
# END STANDALONE LOGGING
fi
ml_start_capture "$BOOTSTRAP_LOG_FILE" || {
  printf '无法初始化日志，请检查权限、日志策略或 MACOS_SCRIPTS_LOG_DIR: %s\n' "$BOOTSTRAP_LOG_FILE" >&2
  exit 1
}

# curl 管道执行（curl ... | zsh）时，${0:A} 无法解析出真实脚本路径，
# REPO_ROOT 不可用且仓库文件不存在。此时必须自包含运行：
# 定义本脚本用到的全部日志函数与工具函数 fallback。
if [[ -f "$REPO_ROOT/lib/utils.sh" ]]; then
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/utils.sh"
else
  # ---- 日志函数 fallback（与 lib/colors.sh 输出风格保持一致）----
  info() { printf '\033[0;34mℹ\033[0m %s\n' "$*"; }
  error() { printf '\033[0;31m✗\033[0m %s\n' "$*" >&2; }
  warning() { printf '\033[0;33m⚠\033[0m %s\n' "$*"; }
  success() { printf '\033[0;32m✓\033[0m %s\n' "$*"; }
  print_header() { printf '\n==== %s ====\n\n' "$1"; }
  print_code() { printf '  %s\n' "$1"; }
  # 独立入口不依赖仓库文件；格式与 lib/utils.sh 保持一致。
  write_log_run_header() {
    local mode="${1:-实际执行}"
    local script_name="${2:-${ZSH_ARGZERO:t}}"
    local started_at="${3:-$(date '+%Y-%m-%d %H:%M:%S %z')}"
    printf '\n===== 运行开始 =====\n开始时间: %s\n脚本: %s\n模式: %s\nPID: %s\n====================\n' \
      "$started_at" "$script_name" "$mode" "$$"
  }

  # ---- 工具函数 fallback ----
  first_line() {
    "$@" 2> /dev/null | awk 'NR == 1 { print; exit }'
  }

  require_command() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || {
      printf '缺少必要命令: %s\n' "$cmd" >&2
      exit 1
    }
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

  resolve_homebrew_bin() {
    if command -v brew >/dev/null 2>&1; then
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

  # 独立管道模式没有公共库；此实现与 lib/utils.sh 保持一致，
  # tests/bootstrap_guard.sh 对两种入口执行相同的状态矩阵。
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

fi

if [[ -f "$REPO_ROOT/setup/lib/homebrew_config.sh" ]]; then
  # shellcheck disable=SC1091
  source "$REPO_ROOT/setup/lib/homebrew_config.sh"
else
  # 防御性 fallback：仅当 lib/utils.sh 未提供 resolve_homebrew_bin 时定义
  if ! typeset -f resolve_homebrew_bin > /dev/null 2>&1; then
    resolve_homebrew_bin() {
      if command -v brew >/dev/null 2>&1; then
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
  fi

  activate_homebrew_environment() {
    local brew_bin="$1"
    local shellenv_content
    shellenv_content="$($brew_bin shellenv)" || return 1
    eval "$shellenv_content"
  }
fi

BOOTSTRAP_LOCK_DIR="${MACOS_SCRIPTS_CONFIG_DIR:-$HOME/.config/macos-scripts}/.bootstrap.lock"
BOOTSTRAP_LOCK_HELD=false
BOOTSTRAP_STAGE="解析参数"
BOOTSTRAP_DEFAULT_RECOVERY="查看上方原始错误并修复问题后，重新运行原 bootstrap 命令；已完成且可用的安装会自动跳过。"
BOOTSTRAP_RECOVERY="$BOOTSTRAP_DEFAULT_RECOVERY"
BOOTSTRAP_INTERRUPT=""
BOOTSTRAP_EXIT_REPORTED=false
BOOTSTRAP_BREW_BIN=""
BOOTSTRAP_CLI_BIN=""
BOOTSTRAP_CLI_VERSION=""
BOOTSTRAP_CONFIG_RESULT="尚未执行"

report_bootstrap_exit() {
  local exit_code="$1"
  [[ "$exit_code" -ne 0 && "$BOOTSTRAP_EXIT_REPORTED" == false ]] || return 0
  BOOTSTRAP_EXIT_REPORTED=true
  if [[ -n "$BOOTSTRAP_INTERRUPT" ]]; then
    warning "bootstrap 已中断（SIG${BOOTSTRAP_INTERRUPT}），阶段: $BOOTSTRAP_STAGE（退出码 $exit_code）"
  else
    error "bootstrap 失败，阶段: $BOOTSTRAP_STAGE（退出码 $exit_code）"
  fi
  info "日志文件位置: $BOOTSTRAP_LOG_FILE"
  info "恢复建议: $BOOTSTRAP_RECOVERY"
}

acquire_bootstrap_lock() {
  [[ "$DRY_RUN" == true ]] && return 0
  mkdir -p "${BOOTSTRAP_LOCK_DIR:h}" || {
    error "无法创建 bootstrap 锁的父目录，请检查权限: ${BOOTSTRAP_LOCK_DIR:h}"
    return 1
  }
  if ! (umask 077; mkdir "$BOOTSTRAP_LOCK_DIR") 2>/dev/null; then
    if [[ -e "$BOOTSTRAP_LOCK_DIR" || -L "$BOOTSTRAP_LOCK_DIR" ]]; then
      error "另一个 bootstrap 可能正在运行，或上次强制终止留下了锁。请先检查 $BOOTSTRAP_LOCK_DIR/pid；确认原进程已结束后，删除该 pid 文件并移除锁目录再重试。"
    else
      error "无法创建 bootstrap 锁，请检查目录权限: $BOOTSTRAP_LOCK_DIR"
    fi
    return 1
  fi
  BOOTSTRAP_LOCK_HELD=true
  printf '%s\n' "$$" > "$BOOTSTRAP_LOCK_DIR/pid" || {
    error "无法写入 bootstrap 锁信息，请检查权限: $BOOTSTRAP_LOCK_DIR"
    return 1
  }
}

cleanup_bootstrap_lock() {
  local exit_code="${1:-$?}"
  trap - EXIT INT TERM HUP
  if [[ "$BOOTSTRAP_LOCK_HELD" == true ]]; then
    if ! { rm -f "$BOOTSTRAP_LOCK_DIR/pid" && rmdir "$BOOTSTRAP_LOCK_DIR"; }; then
      warning "bootstrap 锁清理失败。确认原进程已结束后，请手动清理: $BOOTSTRAP_LOCK_DIR"
    fi
    BOOTSTRAP_LOCK_HELD=false
  fi
  report_bootstrap_exit "$exit_code"
  return "$exit_code"
}

run_command() {
  local description="$1"
  shift

  if [[ "$DRY_RUN" == "true" ]]; then
    info "[dry-run] $description"
    print_code "$*"
    return 0
  fi

  info "$description"
  "$@"
}

confirm_bootstrap() {
  [[ "$DRY_RUN" == "true" ]] && return 0

  if [[ "$YES" == "true" ]]; then
    info "已通过 --yes 跳过交互确认"
    return 0
  fi

  # 管道模式的 stdin 是脚本内容，确认必须单独连接控制终端。
  local tty_fd
  if ! { exec {tty_fd}< /dev/tty; } 2>/dev/null; then
    error "无法访问交互终端。确认需要执行安装后，请添加 --yes 重新运行；预演可使用 --dry-run。"
    return 2
  fi
  local reply=""
  if ! printf '%s' "将检查/安装 Homebrew 和 macos-scripts，并按选项执行配置。是否继续 (y/N): "; then
    exec {tty_fd}<&-
    error "无法向交互终端显示确认提示。请检查终端，或使用 --yes 重新运行。"
    return 2
  fi
  # 回车、EOF 和非 y/Y 输入均按取消处理。
  read -r -u "$tty_fd" reply || reply=""
  exec {tty_fd}<&-
  [[ "$reply" =~ ^[Yy]$ ]]
}

check_bootstrap_architecture() {
  local process_arch translated
  if ! process_arch="$(uname -m)"; then
    error "无法读取运行架构，请检查 uname -m 后重新运行。"
    return 1
  fi
  case "$process_arch" in
    arm64|x86_64) ;;
    *)
      error "不支持的运行架构: ${process_arch:-空}；仅支持 arm64 和 x86_64，请在受支持的 Mac 终端中重新运行。"
      return 1
      ;;
  esac
  info "运行架构: $process_arch"
  if [[ "$process_arch" == x86_64 ]]; then
    require_command sysctl || return 1
    # Intel 上该键可能不存在；仅在查询成功且明确为 1 时判断为 Rosetta。
    # Apple: About the Rosetta translation environment / sysctl.proc_translated。
    if translated="$(sysctl -in sysctl.proc_translated 2>/dev/null)" && [[ "$translated" == 1 ]]; then
      warning "检测到 Rosetta 转译运行（x86_64）。建议在原生终端重新执行，避免新增 Intel Homebrew；可取消当前运行，在终端应用的信息窗口关闭“使用 Rosetta 打开”后重启终端。"
      info "如继续，将按现有规则探测和使用 Homebrew，不自动迁移或重装。"
    fi
  fi
  return 0
}

precheck() {
  print_header "Bootstrap 预检"

  require_command curl || return 1
  require_command uname || return 1
  require_supported_macos || return 1
  check_bootstrap_architecture || return 1

  local os_version
  os_version="$(sw_vers -productVersion)" || return 1

  info "系统版本: $(sw_vers -productName) $os_version"
  info "日志文件位置: $BOOTSTRAP_LOG_FILE"
}

resolve_usable_homebrew_bin() {
  local path_brew candidate candidate_key
  local -a candidates=() failed_candidates=()
  local -A seen=()
  path_brew="$(command -v brew)" || path_brew=""
  [[ -z "$path_brew" ]] || candidates+=("$path_brew")
  candidates+=(/opt/homebrew/bin/brew /usr/local/bin/brew)

  for candidate in "${candidates[@]}"; do
    # 仅用实际路径去重，返回时保留原入口，兼容符号链接。
    candidate="${candidate:a}"
    candidate_key="${candidate:A}"
    [[ -z "${seen[$candidate_key]:-}" ]] || continue
    seen[$candidate_key]=1
    [[ -x "$candidate" ]] || continue
    if "$candidate" --version > /dev/null 2>&1; then
      if (( ${#failed_candidates[@]} > 0 )); then
        # stdout 只返回路径，避免日志混入调用方的命令替换。
        warning "Homebrew 入口不可用: ${(j:、:)failed_candidates}；实际选用: $candidate" >&2
      fi
      printf '%s' "$candidate"
      return 0
    fi
    failed_candidates+=("$candidate")
  done
  return 1
}

run_homebrew_installer() {
  local installer_url="$1"
  local installer_source="$2"
  local installer_script

  BOOTSTRAP_STAGE="下载 ${installer_source} 安装脚本"
  # 下载和执行分开判断：下载失败或部分响应不能被 Bash 当作成功执行。
  if ! installer_script="$(curl -fsSL --connect-timeout "$HOMEBREW_DOWNLOAD_CONNECT_TIMEOUT" --max-time "$HOMEBREW_DOWNLOAD_MAX_TIME" "$installer_url")"; then
    error "Homebrew 安装脚本下载失败（连接上限 ${HOMEBREW_DOWNLOAD_CONNECT_TIMEOUT} 秒，下载上限 ${HOMEBREW_DOWNLOAD_MAX_TIME} 秒）。请检查网络后重试: $installer_url"
    return 1
  fi
  if [[ -z "${installer_script//[[:space:]]/}" ]]; then
    error "Homebrew 安装脚本为空: $installer_url"
    return 1
  fi

  BOOTSTRAP_STAGE="执行 ${installer_source} 安装脚本"
  if [[ "$YES" == "true" ]]; then
    # 仅作用于安装器子进程，避免与用户设置的 INTERACTIVE 冲突。
    env -u INTERACTIVE NONINTERACTIVE=1 /bin/bash -c "$installer_script"
  else
    /bin/bash -c "$installer_script"
  fi
}

install_homebrew_if_needed() {
  print_header "步骤 2：安装 Homebrew"

  local official_url="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
  local mirror_url="https://mirrors.ustc.edu.cn/misc/brew-install.sh"
  local brew_bin=""
  if brew_bin="$(resolve_usable_homebrew_bin)"; then
    BOOTSTRAP_STAGE="激活 Homebrew 环境"
    activate_homebrew_environment "$brew_bin" || return 1
    success "检测到现有 Homebrew: $(first_line "$brew_bin" --version)"
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    local install_prefix=""
    [[ "$YES" == "true" ]] && install_prefix="env -u INTERACTIVE NONINTERACTIVE=1 "
    info "[dry-run] 将先尝试官方安装脚本；失败后复查 brew，仅在仍不可用时切换 USTC"
    print_code "${install_prefix}/bin/bash -c \"\$(curl -fsSL --connect-timeout $HOMEBREW_DOWNLOAD_CONNECT_TIMEOUT --max-time $HOMEBREW_DOWNLOAD_MAX_TIME $official_url)\""
    print_code "${install_prefix}/bin/bash -c \"\$(curl -fsSL --connect-timeout $HOMEBREW_DOWNLOAD_CONNECT_TIMEOUT --max-time $HOMEBREW_DOWNLOAD_MAX_TIME $mirror_url)\""
    return 0
  fi

  warning "未检测到可用的 Homebrew，开始安装"
  if [[ "$YES" == "true" ]]; then
    info "--yes 将为官方和 USTC 安装器设置 NONINTERACTIVE=1；权限不足时请不带 --yes 重试。"
  fi

  local install_status=0
  run_homebrew_installer "$official_url" "Homebrew 官方" || install_status=$?

  # 安装器可能已完成主体安装却在收尾时报错，先验证 brew，避免重复安装。
  if brew_bin="$(resolve_usable_homebrew_bin)"; then
    if [[ "$install_status" -ne 0 ]]; then
      warning "官方安装返回非零（$install_status），但 brew 已可用，跳过 USTC 安装。"
    fi
  else
    warning "官方安装未得到可用的 Homebrew（状态码 $install_status），尝试 USTC 镜像"
    if ! run_homebrew_installer "$mirror_url" "Homebrew USTC"; then
      error "官方及 USTC 安装均未完成。请检查网络和安装器输出；若为权限问题，请在终端不带 --yes 重新运行。日志: $BOOTSTRAP_LOG_FILE"
      return 1
    fi
    BOOTSTRAP_STAGE="验证 Homebrew 可用性"
    brew_bin="$(resolve_usable_homebrew_bin)" || {
      error "USTC 安装脚本已结束，但 brew 仍不可用。请检查安装器输出后重试。日志: $BOOTSTRAP_LOG_FILE"
      return 1
    }
  fi

  BOOTSTRAP_STAGE="激活 Homebrew 环境"
  activate_homebrew_environment "$brew_bin" || return 1
  success "Homebrew 安装完成: $(first_line "$brew_bin" --version)"
}

install_macos_scripts() {
  print_header "步骤 3：安装 macos-scripts"

  local brew_bin
  brew_bin="$(resolve_usable_homebrew_bin)" || {
    if [[ "$DRY_RUN" == "true" ]]; then
      info "[dry-run] 假定 Homebrew 已在上一步安装完成，继续预演 tap/install 流程"
      if [[ "$TAP_REMOTE_URL" == "$DEFAULT_TAP_REMOTE_URL" ]]; then
        print_code "brew tap $TAP_NAME $TAP_REMOTE_URL"
      else
        print_code "brew tap --custom-remote $TAP_NAME $TAP_REMOTE_URL"
      fi
      print_code "brew install $TAP_NAME/$FORMULA_NAME"
      info "[dry-run] 将执行 macos-scripts --version 验证 CLI 可用性"
      return 0
    fi
    error "未找到 brew，可用性校验失败"
    exit 1
  }
  BOOTSTRAP_BREW_BIN="$brew_bin"
  BOOTSTRAP_STAGE="激活 Homebrew 环境"
  activate_homebrew_environment "$brew_bin" || return 1

  local -a tap_command=("$brew_bin" tap "$TAP_NAME" "$TAP_REMOTE_URL")
  if [[ "$TAP_REMOTE_URL" != "$DEFAULT_TAP_REMOTE_URL" ]]; then
    tap_command=("$brew_bin" tap --custom-remote "$TAP_NAME" "$TAP_REMOTE_URL")
  fi

  BOOTSTRAP_STAGE="添加 tap"
  run_command "添加 tap: $TAP_NAME" "${tap_command[@]}" || return 1

  BOOTSTRAP_STAGE="检查 macos-scripts 安装状态"
  if "$brew_bin" list --formula "$FORMULA_NAME" >/dev/null 2>&1; then
    info "检测到已安装 $FORMULA_NAME，跳过安装和升级。"
  else
    BOOTSTRAP_STAGE="安装 macos-scripts"
    run_command "安装 stable formula: $TAP_NAME/$FORMULA_NAME（版本以 tap Formula 为准）" "$brew_bin" install "$TAP_NAME/$FORMULA_NAME" || return 1
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    info "[dry-run] 将执行 macos-scripts --version 验证 CLI 可用性"
    return 0
  fi

  BOOTSTRAP_STAGE="验证 macos-scripts CLI"
  BOOTSTRAP_CLI_BIN="$(command -v macos-scripts)" || {
    error "已安装 formula，但当前 shell 中找不到 macos-scripts，请检查 brew shellenv。日志: $BOOTSTRAP_LOG_FILE"
    exit 1
  }

  local cli_version
  if ! cli_version="$("$BOOTSTRAP_CLI_BIN" --version)"; then
    error "macos-scripts --version 执行失败，停止后续配置。请检查上方错误，必要时执行 brew reinstall $TAP_NAME/$FORMULA_NAME 后重试。日志: $BOOTSTRAP_LOG_FILE"
    return 1
  fi
  BOOTSTRAP_CLI_VERSION="$cli_version"
  info "当前 CLI 版本: $cli_version"
  success "macos-scripts 已可用: $BOOTSTRAP_CLI_BIN"
}

run_post_install_configuration() {
  print_header "步骤 4：接入统一 CLI"

  if [[ "$SKIP_CONFIGURE" == "true" ]]; then
    BOOTSTRAP_CONFIG_RESULT="已跳过（--skip-configure）"
    warning "已通过 --skip-configure 跳过 'macos-scripts setup brew configure'"
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    info "[dry-run] 将执行 'macos-scripts setup brew configure'"
    return 0
  fi

  if ! "$BOOTSTRAP_CLI_BIN" setup brew configure; then
    error "bootstrap 已完成 Homebrew 和 formula 安装，但 CLI 配置阶段失败。"
    error "请稍后手动执行: macos-scripts setup brew configure"
    exit 1
  fi

  BOOTSTRAP_CONFIG_RESULT="已完成"
  success "已通过 CLI 完成 Homebrew 配置链路"
}

print_next_steps() {
  if [[ "$DRY_RUN" == "true" ]]; then
    print_header "Bootstrap dry-run 完成"
    info "本次仅做流程预演，未实际执行安装、CLI 校验或 USTC 配置。"
  else
    print_header "Bootstrap 完成"
    info "Homebrew 路径: $BOOTSTRAP_BREW_BIN"
    info "macos-scripts 路径: $BOOTSTRAP_CLI_BIN"
    info "CLI 实际版本: $BOOTSTRAP_CLI_VERSION"
    info "USTC 配置: $BOOTSTRAP_CONFIG_RESULT"
  fi
  info "日志目录: $MACOS_SCRIPTS_LOG_DIR"
  info "日志文件位置: $BOOTSTRAP_LOG_FILE"
  info "建议继续执行："
  print_code "macos-scripts setup shell"
  print_code "macos-scripts setup packages"
  print_code "macos-scripts setup github"
  info "如果当前 terminal 尚未刷新，可执行："
  print_code "source ~/.zshrc"
  print_code "exec zsh"
}

main() {
  BOOTSTRAP_STAGE="系统预检"
  precheck || exit $?
  BOOTSTRAP_STAGE="获取运行锁"
  BOOTSTRAP_RECOVERY="若已有安装仍在运行，请等待；仅在确认原进程已结束且锁残留时按提示清理，再重新运行原 bootstrap 命令。"
  acquire_bootstrap_lock || exit $?

  BOOTSTRAP_STAGE="安装确认"
  BOOTSTRAP_RECOVERY="在交互终端中重试，或确认需要安装后添加 --yes；预演可使用 --dry-run。"
  if confirm_bootstrap; then
    :
  else
    local confirm_status=$?
    if [[ "$confirm_status" -eq 1 ]]; then
      warning "已取消 bootstrap"
      exit 0
    fi
    exit "$confirm_status"
  fi

  local -a xcode_args=(--timeout 120)
  [[ "$DRY_RUN" == "true" ]] && xcode_args+=(--dry-run)
  BOOTSTRAP_RECOVERY="$BOOTSTRAP_DEFAULT_RECOVERY"
  # Zsh 在函数内 ERR_EXIT 时可能跳过脚本级 EXIT trap；显式退出确保释放锁。
  BOOTSTRAP_STAGE="检查/安装 Xcode 命令行工具"
  ensure_xcode_cli_installed "${xcode_args[@]}" || exit $?
  BOOTSTRAP_STAGE="检查/安装 Homebrew"
  install_homebrew_if_needed || exit $?
  BOOTSTRAP_STAGE="检查 macos-scripts 安装状态"
  install_macos_scripts || exit $?
  BOOTSTRAP_STAGE="配置 Homebrew（USTC）"
  run_post_install_configuration || exit $?
  BOOTSTRAP_STAGE="输出安装结果"
  print_next_steps
}

# 必须在脚本作用域注册；Zsh 函数内的 EXIT trap 会在函数返回时触发。
bootstrap_log_mode="实际执行"
for bootstrap_option in "$@"; do
  [[ "$bootstrap_option" != --dry-run ]] || bootstrap_log_mode="dry-run"
done
# 管道模式的 ZSH_ARGZERO 为 zsh，使用固定脚本名保证两种入口一致。
write_log_run_header "$bootstrap_log_mode" "install.sh"
trap cleanup_bootstrap_lock EXIT
# 信号可能在嵌套函数中触发，显式清理，不依赖 Zsh 随后的 EXIT trap。
trap 'BOOTSTRAP_INTERRUPT=INT; cleanup_bootstrap_lock 130 || :; exit 130' INT
trap 'BOOTSTRAP_INTERRUPT=TERM; cleanup_bootstrap_lock 143 || :; exit 143' TERM
trap 'BOOTSTRAP_INTERRUPT=HUP; cleanup_bootstrap_lock 129 || :; exit 129' HUP
main "$@"
