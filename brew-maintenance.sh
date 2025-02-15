#!/bin/bash

# ███████╗配置区域（用户可修改）████████╗
EXCLUDED_CASKS=(
    "notion"                # 排除Notion
    "zoom"                  # 排除Zoom
    "microsoft-.*"          # 排除所有微软系应用
    "adobe-.*"              # 排除Adobe全家桶
    "android-studio"        # 排除Android Studio
    "docker"                # 排除Docker
    "visual-studio-code"    # 排除VS Code
    "iterm2"                # 排除iTerm2
    "epic-games"            # 排除Epic Games
    "google-chrome"         # 排除Chrome
    "obsidian"              # 排除Obsidian
)

# ███████║主逻辑区（无需修改）████████║
green() { echo -e "\033[32m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }
red() { echo -e "\033[31m$1\033[0m"; }

update_brew() {
    green "\n🔧 正在更新Homebrew..."
    brew update
}

update_formulae() {
    green "\n📦 正在更新常规软件包..."
    brew upgrade
}

update_casks() {
    green "\n🖥️ 正在检测可更新的Cask应用..."
    
    local exclude_pattern=$(IFS="|"; echo "${EXCLUDED_CASKS[*]}")
    
    # 关键修复：精准提取Cask名称
    local outdated_casks=$(brew outdated --cask --greedy 2>/dev/null | \
        awk -F'[ ()]' '{print $1}' | \
        grep -E '^[a-z0-9-]+$' | \
        sort -u)
    
    if [ -z "$outdated_casks" ]; then
        yellow "\n⏳ 没有检测到需要更新的Cask应用"
        return 0
    fi
    
    local total=$(echo "$outdated_casks" | wc -l | tr -d ' ')
    local filtered_casks=$(echo "$outdated_casks" | grep -v -E "^(${exclude_pattern})$")
    local filtered_count=$(echo "$filtered_casks" | wc -l | tr -d ' ')
    
    yellow "\n⏳ 发现 $total 个可更新应用，已排除 $((total - filtered_count)) 个"
    
    local counter=0
    while read -r cask; do
        if [[ -z "$cask" || ! "$cask" =~ ^[a-z0-9-]+$ ]]; then
            red "⚠️ 跳过无效Cask名称: ${cask:-<空值>}"
            continue
        fi
        
        if ! brew info --cask "$cask" &>/dev/null; then
            red "❌ Cask '$cask' 不存在或已失效"
            continue
        fi
        
        ((counter++))
        blue "\n🔍 正在处理 ($counter/$filtered_count): $cask"
        
        if ! brew upgrade --cask "$cask"; then
            red "❌ 更新失败: $cask"
            echo "$(date '+%Y-%m-%d %H:%M:%S') 更新失败: $cask" >> brew_update_errors.log
        fi
    done <<< "$filtered_casks"
}

perform_cleanup() {
    green "\n🗑️ 正在清理系统..."
    brew cleanup
}

# ███████╝执行主程序████████╝
clear
echo "🚀 开始执行Homebrew智能维护"

update_brew
update_formulae
update_casks
perform_cleanup

green "\n✅ 所有操作已完成！建议重启终端使变更生效"