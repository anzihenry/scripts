#!/bin/zsh
# filepath: setup/lib/setup_defaults.sh
# 可通过同名环境变量覆盖；默认继续采用既有镜像。
: "${SETUP_NPM_REGISTRY:=https://registry.npmmirror.com}"
: "${SETUP_PIP_INDEX:=https://mirrors.ustc.edu.cn/pypi/simple}"
: "${SETUP_PIP_HOST:=mirrors.ustc.edu.cn}"
: "${SETUP_GEM_SOURCE:=https://mirrors.ustc.edu.cn/rubygems/}"
: "${SETUP_GOPROXY:=https://goproxy.cn,direct}"
: "${SETUP_GOPATH:=$HOME/Coding/go}"
: "${SETUP_JAVA_HOME:=/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home}"
: "${SETUP_ANDROID_HOME:=$HOME/Library/Android/sdk}"
