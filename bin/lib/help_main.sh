#!/bin/zsh
# filepath: bin/lib/help_main.sh

print_main_help() {
  cat <<EOF
macos-scripts v${MACOS_SCRIPTS_VERSION}

用法:
  macos-scripts <命令> [子命令] [参数]

一级命令:
  setup       初始化与配置开发环境
  maintain    日常维护工具
  release     GitHub Release 发布辅助
  job         launchd 定时任务管理
  lint        Shell 脚本检查与格式化
  help        显示帮助
  version     显示版本

示例:
  macos-scripts setup shell
  macos-scripts setup brew configure
  macos-scripts setup git --domain github.com --type personal
  macos-scripts setup github --force
  macos-scripts maintain brew --dry-run
  macos-scripts maintain installer list
  macos-scripts release verify v0.5.0
  macos-scripts release publish v0.5.0 --yes
  macos-scripts job list
  macos-scripts lint check setup
EOF
}
