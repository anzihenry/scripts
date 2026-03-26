#!/bin/bash
# filepath: maintain/formulaes_casks_updater.sh

# 引入颜色库
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/colors.sh"

# ---------------------- 配置区域 ----------------------
EXCLUDED_CASKS=(
    "microsoft-.*"
    "android-studio"
    "visual-studio-code"
    "docker-desktop"
    "iterm2"
    "google-chrome"
    "feishu"
    "lark"
)

EXCLUDE_PATTERN="^($(IFS="|"; echo "${EXCLUDED_CASKS[*]}"))$"
ERROR_LOG="brew_update_errors.log"

# ---------------------- 工具函数 ----------------------
run_cmd() {
    local cmd="$1"
    local show_output="${2:-true}"
    local output
    if [[ "$show_output" == "true" ]]; then
        eval "$cmd"
    else
        output=$(eval "$cmd" 2>&1)
        echo "$output"
    fi
}

get_outdated_casks() {
    local output
    output=$(brew outdated --cask --greedy 2>/dev/null)
    [[ -z "$output" ]] && return 0
    echo "$output" | awk '{print tolower($1)}' | sort -u
}

cask_exists() {
    local cask="$1"
    brew info --cask "$cask" &>/dev/null
}

log_error() {
    local cask="$1"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "$timestamp 更新失败: $cask" >> "$ERROR_LOG"
    error "❌ 更新失败: $cask (已记录到日志)"
}

# ---------------------- 主流程 ----------------------
clear
print_header "🚀 Homebrew 智能维护工具"
success "开始执行 Homebrew 维护任务..."

# 1. 更新 Homebrew
print_header "🔧 步骤1：更新 Homebrew 本身"
success "正在更新 Homebrew..."
run_cmd "brew update"

# 2. 更新 formulae
print_header "📦 步骤2：更新 Formulae 软件包"
success "正在更新常规软件包..."
run_cmd "brew upgrade"

# 3. 检查并更新 cask
print_header "🖥️ 步骤3：检测并更新 Cask 应用"
success "正在检测可更新的 Cask 应用..."
outdated_casks=($(get_outdated_casks))
total=${#outdated_casks[@]}

if [[ $total -eq 0 ]]; then
    warning "⏳ 没有检测到需要更新的 Cask 应用"
else
    # 过滤排除
    filtered_casks=()
    for cask in "${outdated_casks[@]}"; do
        if [[ ! "$cask" =~ $EXCLUDE_PATTERN ]]; then
            filtered_casks+=("$cask")
        fi
    done
    filtered_count=${#filtered_casks[@]}
    warning "⏳ 发现 $total 个可更新应用，已排除 $((total - filtered_count)) 个"

    idx=1
    for cask in "${filtered_casks[@]}"; do
        info "🔍 正在处理 ($idx/$filtered_count): $cask"
        if ! cask_exists "$cask"; then
            error "❌ Cask '$cask' 不存在或已失效"
            ((idx++))
            continue
        fi
        brew upgrade --cask "$cask"
        if [[ $? -ne 0 ]]; then
            log_error "$cask"
        fi
        ((idx++))
    done
fi

# 4. 清理
print_header "🗑️ 步骤4：清理无用缓存"
success "正在清理系统..."
run_cmd "brew cleanup"

# 5. 总结
print_header "📋 维护总结"
success "✅ 所有操作已完成！建议重启终端使变更生效"