#!/bin/zsh
# filepath: bootstrap/install.sh

set -e
set -u
set -o pipefail

SCRIPT_PATH="${0:A}"
SCRIPT_DIR="${SCRIPT_PATH:h}"
REPO_ROOT="${SCRIPT_DIR:h}"

MACOS_SCRIPTS_LOG_DIR="${MACOS_SCRIPTS_LOG_DIR:-$HOME/Library/Logs/macos-scripts}"
mkdir -p "$MACOS_SCRIPTS_LOG_DIR"
BOOTSTRAP_LOG_FILE="$MACOS_SCRIPTS_LOG_DIR/bootstrap.log"

exec > >(tee -a "$BOOTSTRAP_LOG_FILE") 2>&1

if [[ -f "$REPO_ROOT/lib/colors.sh" ]]; then
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/colors.sh"
else
  info() { printf 'INFO: %s\n' "$*"; }
  success() { printf 'SUCCESS: %s\n' "$*"; }
  warning() { printf 'WARN: %s\n' "$*"; }
  error() { printf 'ERROR: %s\n' "$*" >&2; }
  print_header() { printf '\n==== %s ====\n' "$1"; }
  print_code() { printf '  %s\n' "$1"; }
  highlight() { printf '%s' "$*"; }
  log_time_start() { :; }
  log_time_end() { :; }
fi

REPO_SLUG="anzihenry/scripts"
TAP_NAME="anzihenry/scripts"
FORMULA_NAME="macos-scripts"
BOOTSTRAP_RELEASE_TAG="${BOOTSTRAP_RELEASE_TAG:-v0.1.0}"

YES="false"
DRY_RUN="false"
SKIP_CONFIGURE="false"

usage() {
  cat <<EOF
用法:
  bootstrap/install.sh [选项]

说明:
  独立完成首次 bootstrap：安装 Homebrew、tap 安装 macos-scripts，
  并默认执行 'macos-scripts setup brew configure' 进入统一 CLI 链路。

选项:
  --dry-run         仅打印将执行的步骤，不实际执行
  --yes             跳过交互确认
  --skip-configure  安装完成后不自动执行 'macos-scripts setup brew configure'
  -h, --help        显示帮助

示例:
  zsh bootstrap/install.sh
  zsh bootstrap/install.sh --dry-run
  curl -fsSL https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_RELEASE_TAG}/bootstrap/install.sh | zsh
EOF
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
  if [[ "$YES" == "true" ]]; then
    info "已通过 --yes 跳过交互确认"
    return 0
  fi

  printf '%s' "将安装 Homebrew，并通过 Homebrew tap 安装 macos-scripts。是否继续 (y/N): "
  local reply=""
  read -r reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

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
        error "未知参数: $1"
        echo
        usage
        exit 1
        ;;
    esac
  done
}

require_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || {
    error "缺少必要命令: $cmd"
    exit 1
  }
}

resolve_brew_bin() {
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

activate_brew_for_current_shell() {
  local brew_bin="$1"
  eval "$($brew_bin shellenv)"
}

precheck() {
  print_header "Bootstrap 预检"

  require_command curl
  require_command sw_vers
  require_command uname

  local os_version
  local major_version
  os_version="$(sw_vers -productVersion)"
  major_version="$(printf '%s' "$os_version" | awk -F. '{print $1}')"

  if [[ "$major_version" -lt 14 ]]; then
    error "仅支持 macOS 14 及以上版本，当前版本: $os_version"
    exit 1
  fi

  info "系统版本: $(sw_vers -productName) $os_version"
  info "芯片架构: $(uname -m)"
  info "日志文件位置: $BOOTSTRAP_LOG_FILE"
}

ensure_xcode_cli() {
  print_header "步骤 1：检查 Xcode CLI"

  if xcode-select -p >/dev/null 2>&1; then
    success "Xcode 命令行工具已就绪"
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    info "[dry-run] 将执行 xcode-select --install，并等待安装完成"
    return 0
  fi

  warning "未检测到 Xcode CLI，准备调用 xcode-select --install"
  xcode-select --install || true

  local wait_count=0
  local max_wait=120
  until xcode-select -p >/dev/null 2>&1; do
    info "等待 Xcode CLI 安装完成... (${wait_count}/${max_wait})"
    sleep 5
    ((wait_count++))
    if [[ "$wait_count" -gt "$max_wait" ]]; then
      error "Xcode CLI 安装超时，请先手动完成安装后重试。"
      exit 1
    fi
  done

  success "Xcode 命令行工具已安装"
}

install_homebrew_if_needed() {
  print_header "步骤 2：安装 Homebrew"

  local brew_bin=""
  if brew_bin="$(resolve_brew_bin)"; then
    activate_brew_for_current_shell "$brew_bin"
    success "检测到现有 Homebrew: $($brew_bin --version | head -n1)"
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    info "[dry-run] 将先尝试官方 Homebrew 安装脚本，失败后回退到 USTC 镜像"
    print_code "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    print_code "/bin/bash -c \"\$(curl -fsSL https://mirrors.ustc.edu.cn/misc/brew-install.sh)\""
    return 0
  fi

  warning "未检测到 Homebrew，开始安装"
  set +e
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  local install_status=$?
  set -e

  if [[ "$install_status" -ne 0 ]]; then
    warning "官方安装失败 (状态码 $install_status)，尝试 USTC 镜像"
    /bin/bash -c "$(curl -fsSL https://mirrors.ustc.edu.cn/misc/brew-install.sh)"
  fi

  brew_bin="$(resolve_brew_bin)" || {
    error "Homebrew 安装后仍未找到 brew 可执行文件"
    exit 1
  }
  activate_brew_for_current_shell "$brew_bin"

  success "Homebrew 安装完成: $($brew_bin --version | head -n1)"
}

install_macos_scripts() {
  print_header "步骤 3：安装 macos-scripts"

  local brew_bin
  brew_bin="$(resolve_brew_bin)" || {
    if [[ "$DRY_RUN" == "true" ]]; then
      info "[dry-run] 假定 Homebrew 已在上一步安装完成，继续预演 tap/install 流程"
      print_code "brew tap $TAP_NAME https://github.com/$REPO_SLUG"
      print_code "brew install --HEAD $TAP_NAME/$FORMULA_NAME"
      info "[dry-run] 将验证 macos-scripts CLI 可用性"
      return 0
    fi
    error "未找到 brew，可用性校验失败"
    exit 1
  }
  activate_brew_for_current_shell "$brew_bin"

  run_command "添加 tap: $TAP_NAME" brew tap "$TAP_NAME" "https://github.com/$REPO_SLUG"

  if brew list --formula "$FORMULA_NAME" >/dev/null 2>&1; then
    if [[ "$DRY_RUN" == "true" ]]; then
      info "[dry-run] 检测到已安装 $FORMULA_NAME，将执行 upgrade --fetch-HEAD"
      print_code "brew upgrade --fetch-HEAD $TAP_NAME/$FORMULA_NAME"
    else
      info "检测到已安装 $FORMULA_NAME，尝试升级到最新 HEAD"
      brew upgrade --fetch-HEAD "$TAP_NAME/$FORMULA_NAME" || info "当前已是最新版本或无需升级"
    fi
  else
    run_command "安装 formula: $TAP_NAME/$FORMULA_NAME" brew install --HEAD "$TAP_NAME/$FORMULA_NAME"
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    info "[dry-run] 将验证 macos-scripts CLI 可用性"
    return 0
  fi

  command -v macos-scripts >/dev/null 2>&1 || {
    error "已安装 formula，但当前 shell 中找不到 macos-scripts，请检查 brew shellenv。"
    exit 1
  }

  success "macos-scripts 已可用: $(command -v macos-scripts)"
}

run_post_install_configuration() {
  print_header "步骤 4：接入统一 CLI"

  if [[ "$SKIP_CONFIGURE" == "true" ]]; then
    warning "已通过 --skip-configure 跳过 'macos-scripts setup brew configure'"
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    info "[dry-run] 将执行 'macos-scripts setup brew configure'"
    return 0
  fi

  if ! macos-scripts setup brew configure; then
    error "bootstrap 已完成 Homebrew 和 formula 安装，但 CLI 配置阶段失败。"
    error "请稍后手动执行: macos-scripts setup brew configure"
    exit 1
  fi

  success "已通过 CLI 完成 Homebrew 配置链路"
}

print_next_steps() {
  if [[ "$DRY_RUN" == "true" ]]; then
    print_header "Bootstrap dry-run 完成"
    info "本次仅做流程预演，未实际执行安装。"
  else
    print_header "Bootstrap 完成"
  fi
  info "日志文件位置: $BOOTSTRAP_LOG_FILE"
  info "建议继续执行："
  print_code "macos-scripts setup shell"
  print_code "macos-scripts setup packages"
  print_code "macos-scripts setup github --force"
  info "如果当前 terminal 尚未刷新，可执行："
  print_code "source ~/.zshrc"
  print_code "exec zsh"
}

main() {
  parse_args "$@"
  precheck

  if ! confirm_bootstrap; then
    warning "已取消 bootstrap"
    exit 0
  fi

  ensure_xcode_cli
  install_homebrew_if_needed
  install_macos_scripts
  run_post_install_configuration
  print_next_steps
}

main "$@"