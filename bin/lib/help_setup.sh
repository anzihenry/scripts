#!/bin/zsh
# filepath: bin/lib/help_setup.sh

print_setup_shell_help() {
  cat <<'EOF'
用法:
  macos-scripts setup shell

说明:
  初始化 zsh / oh-my-zsh / powerlevel10k / 常用插件 / 字体。
  安装态日志默认写入 ~/Library/Logs/macos-scripts/setup-shell.log。
  安装态下 .zshrc 备份默认写入 ~/.config/macos-scripts/backups/。

参数:
  当前不接受额外参数。
EOF
}

print_setup_brew_help() {
  cat <<'EOF'
用法:
  macos-scripts setup brew configure [--dry-run]

说明:
  仅校准 Homebrew 镜像、shellenv 和当前 shell 环境。
  该命令面向已具备 Homebrew 的系统，不承担新机首次安装职责；
  若系统尚未安装 Homebrew，请先运行 bootstrap/install.sh。

参数:
  --dry-run        仅预演将执行的配置动作，不修改 ~/.zshrc 或 Homebrew 仓库
EOF
}

print_setup_packages_help() {
  cat <<'EOF'
用法:
  macos-scripts setup packages

说明:
  按 setup/brew.conf.sh 批量安装 Formulae、Casks 和语言环境配置。

参数:
  当前不接受额外参数。
EOF
}

print_setup_git_help() {
  cat <<'EOF'
用法:
  macos-scripts setup git [选项]

说明:
  为任意 Git forge 配置 SSH 密钥、SSH config、公钥上传和连接测试。
  安装态日志默认写入 ~/Library/Logs/macos-scripts/setup-git.log。
  安装态下 SSH config 备份默认写入 ~/.config/macos-scripts/backups/。

选项:
  -d, --domain <domain>         Git 平台域名，默认 github.com
  -t, --type <personal|work>    密钥用途类型，默认 personal
  --force                       强制覆盖现有密钥
  --skip-upload                 跳过 GitHub 公钥上传
  --debug                       显示调试信息
  -h, --help                    显示帮助

示例:
  macos-scripts setup git --domain github.com --type personal
  macos-scripts setup git --domain gitlab.company.com --type work --skip-upload
EOF
}

print_setup_github_help() {
  cat <<'EOF'
用法:
  macos-scripts setup github [选项]

说明:
  GitHub 快捷入口，等价于：
    macos-scripts setup git --domain github.com --type personal

选项:
  -t, --type <personal|work>    密钥用途类型，默认 personal
  --force                       强制覆盖现有密钥
  --skip-upload                 跳过 GitHub 公钥上传
  --debug                       显示调试信息
  -h, --help                    显示帮助

说明:
  如需自定义域名，请改用 `macos-scripts setup git --domain <domain>`。
EOF
}

print_setup_help() {
  cat <<'EOF'
用法:
  macos-scripts setup shell
  macos-scripts setup brew configure
  macos-scripts setup packages
  macos-scripts setup git [参数]
  macos-scripts setup github [参数]

说明:
  shell            安装和配置 zsh / oh-my-zsh / p10k / 字体
  brew configure   仅校准 Homebrew 镜像、shellenv 与当前环境
  packages         按 brew.conf 批量安装软件与语言环境
  git              配置任意 Git forge 的 SSH 密钥与连接
  github           GitHub 快捷入口，等价于 setup git --domain github.com
EOF
}
