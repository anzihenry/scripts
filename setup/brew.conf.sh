#!/bin/zsh
#
# Homebrew 软件包配置文件
# 使用 Shell 数组定义，按类别组织

# ------------------- Formulae (命令行工具) -------------------
FORMULAE_DEV_TOOLS=(
    buf
    cmake
    cmake-docs
    gh
    golangci-lint
    gradle
    ios-deploy
    jq
    lazygit
    mactop
    ncdu
    ninja
    nvm
    pipx
    protobuf
    python
    ruby
    shellcheck
    shfmt
    swiftlint
    swiftly
    tmux
    uv
    watchman
    xcbeautify
    xcode-build-server
    xcodegen
)

# ------------------- Casks (图形界面应用) -------------------
CASKS_DEV_TOOLS=(
    "visual-studio-code"
    "android-studio"
    "xcodes-app"
    "iterm2"
    "itermai"
    "itermbrowserplugin"
    "docker-desktop"
    "zulu@17"
    "requestly"
)

CASKS_SOCIAL=(
    "wechat"
    "whatsapp"
    "telegram"
)

CASKS_DAILY=(
    "google-chrome"
    "iina"
    "transmission"
    "the-unarchiver"
    "bilibili"
    "epic-games"
)

CASKS_OFFICE=(
    "feishu"
    "tencent-meeting"
)

CASKS_PRO=(
    "blender"
    "splashtop-personal"
    "splashtop-streamer"
)

CASKS_AI=(
    "chatgpt"
    "codex-app"
    "lm-studio"
)