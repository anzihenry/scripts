#!/bin/zsh
# filepath: setup/lib/setup_shell_config.sh

# 幂等地更新 shell 配置文件
update_shell_config() {
    local section_name="$1"
    local config_content="$2"
    local rc_file="$HOME/.zshrc"
    write_managed_block "$rc_file" "$section_name" "macos-setup" "$config_content"
    success "${section_name} 环境配置已更新"
}
