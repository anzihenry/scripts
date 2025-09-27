#!/bin/zsh
# Homebrew 安装辅助函数库
# 提供批量安装、重试、失败收集与日志汇总能力，便于在各脚本中复用。

# ===== 日志函数兜底 =====
if ! typeset -f log_info >/dev/null 2>&1; then
  log_info()   { echo "[INFO] $*" >&2; }
  log_warn()   { echo "[WARN] $*" >&2; }
  log_error()  { echo "[ERROR] $*" >&2; }
  log_debug()  { [ "${DEBUG:-false}" = "true" ] && echo "[DEBUG] $*" >&2 || true; }
  log_success(){ echo "[SUCCESS] $*" >&2; }
  log_fatal()  { echo "[FATAL] $*" >&2; exit 1; }
  print_header(){ echo "==== $1 ===="; }
  print_table_row() { printf '%-20s : %s\n' "$1" "$2"; }
  success()    { log_success "$@"; }
  warning()    { log_warn "$@"; }
fi

# ===== 全局状态 =====
: "${BH_DEFAULT_RETRIES:=2}"
BH_INSTALLED_ITEMS=()
BH_SKIPPED_ITEMS=()
BH_FAILED_ITEMS=()
BH_DRY_RUN_ITEMS=()

bh_reset_summary() {
  BH_INSTALLED_ITEMS=()
  BH_SKIPPED_ITEMS=()
  BH_FAILED_ITEMS=()
  BH_DRY_RUN_ITEMS=()
}

bh_require_commands() {
  local missing=()
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "缺少命令: ${missing[*]}"
    return 1
  fi
  return 0
}

bh__is_installed() {
  local type="$1"
  local item="$2"
  if [[ "$type" = "cask" ]]; then
    brew list --cask "$item" &>/dev/null
  else
    brew list "$item" &>/dev/null
  fi
}

bh__install_command() {
  local mode="$1"   # install / reinstall
  local type="$2"   # formula / cask
  shift 2
  local args=()
  if [[ "$mode" = "reinstall" ]]; then
    args=(brew reinstall)
  else
    args=(brew install)
  fi
  [[ "$type" = "cask" ]] && args+=(--cask)
  args+=("$@")
  "${args[@]}"
}

bh_install_packages() {
  local type="formula"
  local dry_run="${BH_DRY_RUN:-false}"
  local force="false"
  local retries="$BH_DEFAULT_RETRIES"
  local label="Homebrew 包"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --formulae|--formula|--formulas) type="formula"; shift ;;
      --cask|--casks) type="cask"; shift ;;
      --dry-run) dry_run="true"; shift ;;
      --force) force="true"; shift ;;
      --retries) retries="${2:-1}"; shift 2 ;;
      --label) label="${2:-Homebrew 包}"; shift 2 ;;
      --) shift; break ;;
      -h|--help)
        echo "用法: bh_install_packages [--cask] [--dry-run] [--force] [--retries N] [--label 名称] item1 item2 ..."
        return 0
        ;;
      *) break ;;
    esac
  done

  local items=("$@")
  [[ ${#items[@]} -gt 0 ]] || { log_info "$label：未提供安装项"; return 0; }

  command -v brew >/dev/null 2>&1 || {
    log_error "brew 未安装，无法执行 $label";
    return 1
  }

  [[ "$retries" =~ ^[0-9]+$ ]] || retries=1
  (( retries < 1 )) && retries=1

  local to_install=()
  local already=()
  local item
  for item in "${items[@]}"; do
    if [[ "$force" != "true" ]] && bh__is_installed "$type" "$item"; then
      already+=("$item")
      BH_SKIPPED_ITEMS+=("$item")
      log_debug "$label: $item 已安装，跳过"
      continue
    fi
    to_install+=("$item")
  done

  if [[ ${#already[@]} -gt 0 ]]; then
    log_info "$label：已存在 ${#already[@]} 项 -> ${already[*]}"
  fi

  if [[ ${#to_install[@]} -eq 0 ]]; then
    success "$label：无需额外安装"
    return 0
  fi

  if [[ "$dry_run" = "true" ]]; then
    BH_DRY_RUN_ITEMS+=("${to_install[@]}")
    warning "$label：Dry run 模式，将安装 -> ${to_install[*]}"
    return 0
  fi

  local bulk_mode="install"
  [[ "$force" = "true" ]] && bulk_mode="reinstall"

  set +e
  bh__install_command "$bulk_mode" "$type" "${to_install[@]}"
  local status=$?
  set -e

  if [[ $status -eq 0 ]]; then
    BH_INSTALLED_ITEMS+=("${to_install[@]}")
    success "$label：批量处理成功（${#to_install[@]} 项）"
    return 0
  fi

  warning "$label：批量处理失败，开始逐项安装（重试 ${retries} 次）"
  local failed=()
  for item in "${to_install[@]}"; do
    local attempt=1
    local ok=false
    while (( attempt <= retries )); do
      set +e
      bh__install_command "$bulk_mode" "$type" "$item"
      local ret=$?
      set -e
      if [[ $ret -eq 0 ]]; then
        ok=true
        break
      fi
      warning "$label：$item 第 $attempt/$retries 次安装失败 (状态码 $ret)"
      sleep 2
      (( attempt++ ))
    done
    if $ok; then
      BH_INSTALLED_ITEMS+=("$item")
    else
      failed+=("$item")
      BH_FAILED_ITEMS+=("$item")
    fi
  done

  if [[ ${#failed[@]} -gt 0 ]]; then
    log_error "$label：以下项目安装失败 -> ${failed[*]}"
    return 1
  fi

  success "$label：全部安装完成"
  return 0
}

bh_print_summary() {
  local title="${1:-Homebrew 安装报告}"
  print_header "$title"

  local installed="${BH_INSTALLED_ITEMS[*]:-}";
  local skipped="${BH_SKIPPED_ITEMS[*]:-}";
  local dryrun="${BH_DRY_RUN_ITEMS[*]:-}";
  local failed="${BH_FAILED_ITEMS[*]:-}"

  print_table_row "新安装" "${installed:-无}" 18
  print_table_row "已存在" "${skipped:-无}" 18
  if [[ -n "$dryrun" ]]; then
    print_table_row "Dry Run" "$dryrun" 18
  fi

  if [[ -n "$failed" ]]; then
    warning "安装失败 (${#BH_FAILED_ITEMS[@]}): $failed"
  else
    success "所有 Homebrew 包处理完毕"
  fi
}
