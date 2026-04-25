#!/bin/zsh
# filepath: setup/lib/setup_lang_env.sh

install_node() {
    print_header "配置 Node.js 环境"
    brew list nvm &>/dev/null || brew install nvm
    mkdir -p ~/.nvm

    local nvm_config_content
    nvm_config_content=$(cat <<'EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$(brew --prefix)/opt/nvm/nvm.sh" ] && \. "$(brew --prefix)/opt/nvm/nvm.sh"
[ -s "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm"
EOF
)
    update_shell_config "NVM" "$nvm_config_content"
    eval "$nvm_config_content"

    nvm install --lts --latest-npm
    npm config set registry https://registry.npmmirror.com
}

install_python() {
    print_header "配置 Python 环境"
    brew list python &>/dev/null || brew install python

    local python_config_content='export PATH="$(brew --prefix python)/libexec/bin:$PATH"'
    update_shell_config "Python Env" "$python_config_content"

    local pip_config_path="$HOME/.pip/pip.conf"
    local pip_config_content
    pip_config_content=$(cat <<EOF
[global]
index-url = https://mirrors.ustc.edu.cn/pypi/simple
trusted-host = mirrors.ustc.edu.cn
EOF
)
    write_managed_file "$pip_config_path" "$pip_config_content" "false" "644"
}

install_ruby() {
    print_header "配置 Ruby 环境"
    brew list ruby &>/dev/null || brew install ruby

    local ruby_config_content
    ruby_config_content=$(cat <<'EOF'
export PATH="$(brew --prefix ruby)/bin:$PATH"
export LDFLAGS="-L$(brew --prefix ruby)/lib"
export CPPFLAGS="-I$(brew --prefix ruby)/include"
EOF
)
    update_shell_config "Ruby Env" "$ruby_config_content"

    gem sources --add https://mirrors.ustc.edu.cn/rubygems/ --remove https://rubygems.org/ > /dev/null
}

install_go() {
    print_header "配置 Go 环境"
    brew list go &>/dev/null || brew install go

    local go_config_content
    go_config_content=$(cat <<'EOF'
export GOPATH="$HOME/Coding/go"
export PATH="$GOPATH/bin:$PATH"
export GOPROXY="https://goproxy.cn,direct"
EOF
)
    update_shell_config "Go Env" "$go_config_content"

    mkdir -p $HOME/Coding/go/{src,bin,pkg}
}

config_android_and_java() {
    print_header "配置 Android 和 Java 环境"
    local android_java_config_content
    android_java_config_content=$(cat <<'EOF'
export JAVA_HOME="/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools"
EOF
)
    update_shell_config "Android & Java Env" "$android_java_config_content"
}
