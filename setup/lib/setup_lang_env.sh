#!/bin/zsh
# filepath: setup/lib/setup_lang_env.sh

install_node() {
    print_header "配置 Node.js 环境"
    brew list nvm &>/dev/null || brew install nvm
    mkdir -p ~/.nvm

    local nvm_config_content
    nvm_config_content=$(cat <<'EOF'
export NVM_DIR="$HOME/.nvm"
if [ -s "$(brew --prefix)/opt/nvm/nvm.sh" ]; then . "$(brew --prefix)/opt/nvm/nvm.sh"; fi
if [ -s "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm" ]; then . "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm"; fi
EOF
)
    update_shell_config "NVM" "$nvm_config_content"
    eval "$nvm_config_content"

    if nvm version 'lts/*' >/dev/null 2>&1; then
        nvm use --lts || return 1
    else
        nvm install --lts || return 1
    fi
    local registry="$(npm config get registry)"
    [[ "${registry%/}" == https://registry.npmmirror.com ]] || npm config set registry https://registry.npmmirror.com
}

install_python() {
    print_header "配置 Python 环境"
    brew list python &>/dev/null || brew install python

    local python_config_content='typeset -U path PATH
export PATH="$(brew --prefix python)/libexec/bin:$PATH"'
    update_shell_config "Python Env" "$python_config_content"

    local pip_config_path="$HOME/.pip/pip.conf"
    set_ini_value "$pip_config_path" global index-url https://mirrors.ustc.edu.cn/pypi/simple || return 1
    set_ini_value "$pip_config_path" global trusted-host mirrors.ustc.edu.cn || return 1

}

install_ruby() {
    print_header "配置 Ruby 环境"
    brew list ruby &>/dev/null || brew install ruby

    local ruby_config_content
    ruby_config_content=$(cat <<'EOF'
typeset -U path PATH
export PATH="$(brew --prefix ruby)/bin:$PATH"
export LDFLAGS="-L$(brew --prefix ruby)/lib"
export CPPFLAGS="-I$(brew --prefix ruby)/include"
EOF
)
    update_shell_config "Ruby Env" "$ruby_config_content"

    local ruby_prefix gem_bin sources
    ruby_prefix="$(brew --prefix ruby)" || return 1
    [[ -n "$ruby_prefix" ]] || return 1
    gem_bin="$ruby_prefix/bin/gem"
    sources="$("$gem_bin" sources --list)" || return 1
    if ! printf '%s\n' "$sources" | grep -Fxq https://mirrors.ustc.edu.cn/rubygems/; then
        "$gem_bin" sources --add https://mirrors.ustc.edu.cn/rubygems/ || return 1
    fi
    if printf '%s\n' "$sources" | grep -Fxq https://rubygems.org/; then
        "$gem_bin" sources --remove https://rubygems.org/ || return 1
    fi
}

install_go() {
    print_header "配置 Go 环境"
    brew list go &>/dev/null || brew install go

    local go_config_content
    go_config_content=$(cat <<'EOF'
export GOPATH="$HOME/Coding/go"
typeset -U path PATH
export PATH="$GOPATH/bin:$PATH"
export GOPROXY="https://goproxy.cn,direct"
EOF
)
    update_shell_config "Go Env" "$go_config_content"

    mkdir -p "$HOME/Coding/go/"{src,bin,pkg}
}

config_android_and_java() {
    print_header "配置 Android 和 Java 环境"
    local android_java_config_content
    android_java_config_content=$(cat <<'EOF'
export JAVA_HOME="/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
typeset -U path PATH
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools"
EOF
)
    update_shell_config "Android & Java Env" "$android_java_config_content"
}
