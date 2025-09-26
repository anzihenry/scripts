#!/bin/zsh
#
# Homebrew 软件包配置文件
# 使用 Shell 数组定义，按类别组织

# ------------------- Formulae (命令行工具) -------------------
FORMULAE_DEV_TOOLS=(
    "cmake"
    "cmake-docs"
    "ninja"
    "ncdu"
    "pipx"
    "protobuf"
    "tmux"
    "jq"
    "mactop"
    "uv"
    "gh"
)

# ------------------- Casks (图形界面应用) -------------------
CASKS_DEV_TOOLS=(
    "visual-studio-code"
    "android-studio"
    "xcodes-app"
    "github-copilot-for-xcode"
    "iterm2"
    "sourcetree"
    "docker-desktop"
    "zulu@17"
)

CASKS_SOCIAL=(
    "wechat"
    "whatsapp"
    "telegram"
    "discord"
)

CASKS_DAILY=(
    "google-chrome"
    "iina"
    "transmission"
    "hammerspoon"
    "the-unarchiver"
    "bilibili"
    "epic-games"
)

CASKS_OFFICE=(
    "feishu"
    "lark"
    "tencent-meeting"
)

CASKS_PRO=(
    "blender"
    "splashtop-personal"
    "splashtop-streamer"
)

CASKS_AI=(
    "chatgpt"
    "lm-studio"
)