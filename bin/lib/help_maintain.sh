#!/bin/zsh
# filepath: bin/lib/help_maintain.sh

print_maintain_brew_help() {
  cat <<'EOF'
用法:
  macos-scripts maintain brew [选项]

说明:
  更新 Homebrew 元数据、Formulae、Cask，并执行 cleanup。

选项:
  --dry-run         仅展示将执行的命令，不实际更新
  --yes             跳过执行前确认
  --force           包含默认排除的 Cask 一并升级
  --skip-formulae   跳过 Formulae 更新
  --skip-casks      跳过 Cask 更新
  --skip-cleanup    跳过 brew cleanup
  -h, --help        显示帮助
EOF
}

print_maintain_installer_help() {
  cat <<'EOF'
用法:
  macos-scripts maintain installer list [--verbose]
  macos-scripts maintain installer download --version <x.y[.z]> [--force] [--verbose]
  macos-scripts maintain installer create --volume <path> [--installer-path <path>] [--version <x.y[.z]>] [-y|--yes] [--force] [--verbose]

说明:
  list             列出可用完整安装器版本
  download         下载指定版本完整安装器
  create           制作 USB 启动盘
  日志             默认写入 ~/Library/Logs/macos-scripts/macos-installer.log
EOF
}

print_maintain_installer_list_help() {
  cat <<'EOF'
用法:
  macos-scripts maintain installer list [--verbose]

选项:
  --verbose, -v    显示调试信息
  -h, --help       显示帮助
EOF
}

print_maintain_installer_download_help() {
  cat <<'EOF'
用法:
  macos-scripts maintain installer download --version <x.y[.z]> [--force] [--verbose]

选项:
  --version <ver>  指定完整安装器版本，例如 14.6.1
  --force, -f      若已存在则强制重新下载
  --verbose, -v    显示调试信息
  -h, --help       显示帮助
EOF
}

print_maintain_installer_create_help() {
  cat <<'EOF'
用法:
  macos-scripts maintain installer create --volume <path> [--installer-path <path>] [--version <x.y[.z]>] [-y|--yes] [--force] [--verbose]

选项:
  --volume <path>          目标卷路径，例如 /Volumes/MyUSB
  --installer-path <path>  指定安装器 .app 路径
  --version <ver>          按版本自动匹配安装器
  -y, --yes                跳过交互确认
  --force, -f              覆盖卷上现有内容
  --verbose, -v            显示调试信息
  -h, --help               显示帮助
EOF
}

print_maintain_help() {
  cat <<'EOF'
用法:
  macos-scripts maintain brew [参数]
  macos-scripts maintain installer <list|download|create> [参数]

说明:
  brew             更新 Homebrew / Formulae / Cask / cleanup
  installer        管理 macOS 完整安装器和 USB 启动盘
EOF
}
