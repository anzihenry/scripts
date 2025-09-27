#!/bin/bash
# 通用颜色输出库
# 使用方法: source "$(dirname "$0")/../lib/colors.sh"

# ===== 颜色配置 =====
# 支持环境变量控制
: ${NO_COLOR:=false}
: ${FORCE_COLOR:=false}

# 检测是否支持颜色输出
_supports_color() {
    [[ "$FORCE_COLOR" == "true" ]] && return 0
    [[ "$NO_COLOR" == "true" ]] && return 1
    [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]] && return 0
    return 1
}

# 颜色代码定义
if _supports_color; then
    # 基础颜色
    export COLOR_RED='\033[0;31m'
    export COLOR_GREEN='\033[0;32m'
    export COLOR_YELLOW='\033[1;33m'
    export COLOR_BLUE='\033[0;34m'
    export COLOR_PURPLE='\033[0;35m'
    export COLOR_CYAN='\033[0;36m'
    export COLOR_WHITE='\033[1;37m'
    export COLOR_GRAY='\033[0;37m'
    
    # 高亮颜色
    export COLOR_BRIGHT_RED='\033[1;31m'
    export COLOR_BRIGHT_GREEN='\033[1;32m'
    export COLOR_BRIGHT_YELLOW='\033[1;33m'
    export COLOR_BRIGHT_BLUE='\033[1;34m'
    export COLOR_BRIGHT_PURPLE='\033[1;35m'
    export COLOR_BRIGHT_CYAN='\033[1;36m'
    
    # 背景色
    export COLOR_BG_RED='\033[41m'
    export COLOR_BG_GREEN='\033[42m'
    export COLOR_BG_YELLOW='\033[43m'
    export COLOR_BG_BLUE='\033[44m'
    
    # 样式
    export COLOR_BOLD='\033[1m'
    export COLOR_DIM='\033[2m'
    export COLOR_UNDERLINE='\033[4m'
    export COLOR_BLINK='\033[5m'
    export COLOR_REVERSE='\033[7m'
    
    # 重置
    export COLOR_RESET='\033[0m'
    export COLOR_NC='\033[0m'  # No Color (兼容别名)
    
    # 兼容性别名（保持向后兼容）
    export RED="$COLOR_RED"
    export GREEN="$COLOR_GREEN"
    export YELLOW="$COLOR_YELLOW"
    export BLUE="$COLOR_BLUE"
    export NC="$COLOR_NC"
else
    # 禁用颜色时设为空
    export COLOR_RED='' COLOR_GREEN='' COLOR_YELLOW='' COLOR_BLUE=''
    export COLOR_PURPLE='' COLOR_CYAN='' COLOR_WHITE='' COLOR_GRAY=''
    export COLOR_BRIGHT_RED='' COLOR_BRIGHT_GREEN='' COLOR_BRIGHT_YELLOW=''
    export COLOR_BRIGHT_BLUE='' COLOR_BRIGHT_PURPLE='' COLOR_BRIGHT_CYAN=''
    export COLOR_BG_RED='' COLOR_BG_GREEN='' COLOR_BG_YELLOW='' COLOR_BG_BLUE=''
    export COLOR_BOLD='' COLOR_DIM='' COLOR_UNDERLINE='' COLOR_BLINK='' COLOR_REVERSE=''
    export COLOR_RESET='' COLOR_NC=''
    export RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

# ===== 日志函数 =====
# 基础日志函数
log_info() {
    echo -e "${COLOR_GREEN}[INFO]${COLOR_NC} $*" >&2
}

log_warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_NC} $*" >&2
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_NC} $*" >&2
}

log_debug() {
    [[ "${DEBUG:-false}" == "true" ]] && echo -e "${COLOR_BLUE}[DEBUG]${COLOR_NC} $*" >&2 || true
}

log_success() {
    echo -e "${COLOR_BRIGHT_GREEN}[SUCCESS]${COLOR_NC} $*" >&2
}

log_fatal() {
    echo -e "${COLOR_BG_RED}${COLOR_WHITE}[FATAL]${COLOR_NC} $*" >&2
    exit 1
}

# ===== 计时工具 =====
__color_timer_key() {
    local raw="${1:-default}"
    # 转换成仅包含字母数字与下划线的大写形式，便于作为变量名
    echo "${raw//[^A-Za-z0-9]/_}" | tr '[:lower:]' '[:upper:]'
}

__color_format_duration() {
    local total="${1:-0}"
    if ! [[ "$total" =~ ^[0-9]+$ ]]; then
        echo "${total}s"
        return 0
    fi

    local hours=$(( total / 3600 ))
    local minutes=$(( (total % 3600) / 60 ))
    local seconds=$(( total % 60 ))
    local parts=()

    (( hours > 0 )) && parts+=("${hours}h")
    (( minutes > 0 )) && parts+=("${minutes}m")
    parts+=("${seconds}s")

    printf "%s" "${parts[*]}"
}

log_time_start() {
    local key="${1:-default}"
    local message="${2:-}"
    local var="__COLOR_TIMER_$(__color_timer_key "$key")"
    local now
    now="$(date +%s 2>/dev/null || printf '%s' "${EPOCHSECONDS:-0}")"
    eval "$var=$now"
    [[ -n "$message" ]] && log_info "$message (开始)"
}

log_time_end() {
    local key="${1:-default}"
    local message="${2:-任务完成}"
    local status="${3:-success}"
    local var="__COLOR_TIMER_$(__color_timer_key "$key")"
    local start=""
    eval "start=\${$var:-}"

    if [[ -z "$start" ]]; then
        log_warn "未找到计时器：$key"
        return 1
    fi

    local now
    now="$(date +%s 2>/dev/null || printf '%s' "${EPOCHSECONDS:-0}")"
    local duration=$(( now - start ))
    local formatted
    formatted="$(__color_format_duration "$duration")"

    case "$status" in
        success|ok)
            log_success "$message，耗时 $formatted"
            ;;
        warn|warning)
            log_warn "$message，耗时 $formatted"
            ;;
        *)
            log_error "$message，耗时 $formatted"
            ;;
    esac

    eval "unset $var"
}

# 带图标的日志函数
success() {
    echo -e "${COLOR_GREEN}✓${COLOR_NC} $*"
}

warning() {
    echo -e "${COLOR_YELLOW}⚠${COLOR_NC} $*"
}

error() {
    echo -e "${COLOR_RED}✗${COLOR_NC} $*"
}

info() {
    echo -e "${COLOR_BLUE}ℹ${COLOR_NC} $*"
}

# ===== 高级输出函数 =====
# 标题输出
print_header() {
    local title="$1"
    local char="${2:-=}"
    local width="${3:-60}"
    
    echo
    echo -e "${COLOR_BOLD}${COLOR_CYAN}$(printf "%*s" "$width" | tr ' ' "$char")${COLOR_NC}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN} $title ${COLOR_NC}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}$(printf "%*s" "$width" | tr ' ' "$char")${COLOR_NC}"
    echo
}

# 分割线
print_separator() {
    local char="${1:--}"
    local width="${2:-60}"
    echo -e "${COLOR_GRAY}$(printf "%*s" "$width" | tr ' ' "$char")${COLOR_NC}"
}

# 进度指示
print_step() {
    local step="$1"
    local total="$2"
    local description="$3"
    echo -e "${COLOR_BOLD}${COLOR_BLUE}[$step/$total]${COLOR_NC} $description"
}

# 高亮文本
highlight() {
    echo -e "${COLOR_BOLD}${COLOR_YELLOW}$*${COLOR_NC}"
}

# 代码块输出
print_code() {
    local code="$1"
    echo -e "${COLOR_GRAY}┌─────────────────────────────────────────┐${COLOR_NC}"
    echo -e "${COLOR_GRAY}│${COLOR_NC} ${COLOR_CYAN}$code${COLOR_NC}"
    echo -e "${COLOR_GRAY}└─────────────────────────────────────────┘${COLOR_NC}"
}

# 表格行输出
print_table_row() {
    local key="$1"
    local value="$2"
    local key_width="${3:-20}"
    printf "${COLOR_BOLD}%-${key_width}s${COLOR_NC} : ${COLOR_GREEN}%s${COLOR_NC}\n" "$key" "$value"
}

# ===== 交互函数 =====
# 确认提示
confirm() {
    local prompt="${1:-继续操作}"
    local default="${2:-N}"
    
    if [[ "$default" == "Y" ]]; then
        echo -ne "${COLOR_YELLOW}$prompt (Y/n): ${COLOR_NC}"
    else
        echo -ne "${COLOR_YELLOW}$prompt (y/N): ${COLOR_NC}"
    fi
    
    read -r response
    case "$response" in
        [Yy]*) return 0 ;;
        [Nn]*) return 1 ;;
        "") [[ "$default" == "Y" ]] && return 0 || return 1 ;;
        *) confirm "$prompt" "$default" ;;
    esac
}

# 选择菜单
select_option() {
    local prompt="$1"
    shift
    local options=("$@")
    
    echo -e "${COLOR_BOLD}$prompt${COLOR_NC}"
    for i in "${!options[@]}"; do
        echo -e "  ${COLOR_CYAN}$((i+1)))${COLOR_NC} ${options[i]}"
    done
    
    while true; do
        echo -ne "${COLOR_YELLOW}请选择 (1-${#options[@]}): ${COLOR_NC}"
        read -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#options[@]})); then
            echo $((choice-1))
            return 0
        fi
        error "无效选择，请输入 1-${#options[@]} 之间的数字"
    done
}

# ===== 工具函数 =====
# 检查颜色支持
check_color_support() {
    if _supports_color; then
        echo "✓ 支持颜色输出"
    else
        echo "✗ 不支持颜色输出"
    fi
}

# 颜色测试
test_colors() {
    echo "=== 颜色测试 ==="
    echo -e "${COLOR_RED}红色文本${COLOR_NC}"
    echo -e "${COLOR_GREEN}绿色文本${COLOR_NC}"
    echo -e "${COLOR_YELLOW}黄色文本${COLOR_NC}"
    echo -e "${COLOR_BLUE}蓝色文本${COLOR_NC}"
    echo -e "${COLOR_PURPLE}紫色文本${COLOR_NC}"
    echo -e "${COLOR_CYAN}青色文本${COLOR_NC}"
    echo -e "${COLOR_BOLD}粗体文本${COLOR_NC}"
    echo -e "${COLOR_UNDERLINE}下划线文本${COLOR_NC}"
    echo -e "${COLOR_BG_RED}${COLOR_WHITE}红色背景${COLOR_NC}"
    
    echo -e "\n=== 日志函数测试 ==="
    log_info "这是信息日志"
    log_warn "这是警告日志"
    log_error "这是错误日志"
    log_debug "这是调试日志"
    log_success "这是成功日志"
    
    echo -e "\n=== 图标函数测试 ==="
    success "成功信息"
    warning "警告信息"
    error "错误信息"
    info "普通信息"
}

# 显示使用帮助
show_color_help() {
    cat << 'EOF'
颜色库使用说明:

1. 引入库文件:
   source "$(dirname "$0")/../lib/colors.sh"

2. 环境变量控制:
   NO_COLOR=true     # 禁用颜色
   FORCE_COLOR=true  # 强制启用颜色
   DEBUG=true        # 启用调试输出

3. 基础用法:
   echo -e "${COLOR_RED}红色文本${COLOR_NC}"
   success "成功信息"
   log_error "错误信息"

4. 高级功能:
   print_header "标题"
   confirm "是否继续" "Y"
   choice=$(select_option "选择选项" "选项1" "选项2")

EOF
}

# ===== 库初始化完成标记 =====
export COLORS_LIB_LOADED=true

# 如果直接执行此文件，运行测试
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-test}" in
        test) test_colors ;;
        help) show_color_help ;;
        check) check_color_support ;;
        *) echo "用法: $0 [test|help|check]" ;;
    esac
fi