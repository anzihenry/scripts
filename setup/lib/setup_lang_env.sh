#!/bin/zsh
# filepath: setup/lib/setup_lang_env.sh
source "${${(%):-%x}:A:h}/setup_defaults.sh"

install_node() {
    print_header "配置 Node.js 环境"
    brew list nvm &>/dev/null || brew install nvm || return 1
    mkdir -p ~/.nvm || return 1

    local nvm_config_content
    nvm_config_content=$(cat <<'EOF'
export NVM_DIR="$HOME/.nvm"
if [ -s "$(brew --prefix)/opt/nvm/nvm.sh" ]; then . "$(brew --prefix)/opt/nvm/nvm.sh"; fi
if [ -s "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm" ]; then . "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm"; fi
EOF
)
    update_shell_config "NVM" "$nvm_config_content" || return 1
    eval "$nvm_config_content" || return 1

    if nvm version 'lts/*' >/dev/null 2>&1; then
        nvm use --lts || return 1
    else
        nvm install --lts || return 1
    fi
    local registry
    registry="$(npm config get registry)" || return 1
    [[ "${registry%/}" == "${SETUP_NPM_REGISTRY%/}" ]] || npm config set registry "$SETUP_NPM_REGISTRY" || return 1
}

install_python() {
    print_header "配置 Python 环境"
    brew list python &>/dev/null || brew install python || return 1

    local python_config_content='typeset -U path PATH
export PATH="$(brew --prefix python)/libexec/bin:$PATH"'
    update_shell_config "Python Env" "$python_config_content" || return 1

    local pip_config_path="$HOME/.pip/pip.conf"
    set_ini_values "$pip_config_path" global index-url "$SETUP_PIP_INDEX" trusted-host "$SETUP_PIP_HOST" || return 1

}

install_ruby() {
    print_header "配置 Ruby 环境"
    brew list ruby &>/dev/null || brew install ruby || return 1

    local ruby_config_content
    ruby_config_content=$(cat <<'EOF'
typeset -U path PATH
export PATH="$(brew --prefix ruby)/bin:$PATH"
export LDFLAGS="-L$(brew --prefix ruby)/lib"
export CPPFLAGS="-I$(brew --prefix ruby)/include"
EOF
)
    update_shell_config "Ruby Env" "$ruby_config_content" || return 1

    local ruby_prefix gem_bin sources
    ruby_prefix="$(brew --prefix ruby)" || return 1
    [[ -n "$ruby_prefix" ]] || return 1
    gem_bin="$ruby_prefix/bin/gem"
    sources="$("$gem_bin" sources --list)" || return 1
    if ! printf '%s\n' "$sources" | grep -Fxq -- "$SETUP_GEM_SOURCE"; then
        "$gem_bin" sources --add "$SETUP_GEM_SOURCE" || return 1
    fi
    if [[ "$SETUP_GEM_SOURCE" != https://rubygems.org/ ]] && printf '%s\n' "$sources" | grep -Fxq https://rubygems.org/; then
        "$gem_bin" sources --remove https://rubygems.org/ || return 1
    fi
}

install_go() {
    print_header "配置 Go 环境"
    brew list go &>/dev/null || brew install go || return 1

    local go_config_content
    go_config_content="export GOPATH=${(q)SETUP_GOPATH}
typeset -U path PATH
export PATH=\"\$GOPATH/bin:\$PATH\"
export GOPROXY=${(q)SETUP_GOPROXY}"
    update_shell_config "Go Env" "$go_config_content" || return 1

    mkdir -p "$SETUP_GOPATH/"{src,bin,pkg} || return 1
}

config_android_and_java() {
    print_header "配置 Android 和 Java 环境"
    local android_java_config_content
    android_java_config_content="export JAVA_HOME=${(q)SETUP_JAVA_HOME}
export ANDROID_HOME=${(q)SETUP_ANDROID_HOME}
typeset -U path PATH
export PATH=\"\$PATH:\$ANDROID_HOME/emulator:\$ANDROID_HOME/platform-tools\""
    update_shell_config "Android & Java Env" "$android_java_config_content" || return 1
}
