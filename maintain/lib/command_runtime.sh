#!/bin/zsh
# filepath: maintain/lib/command_runtime.sh
# 兼容旧导入路径；实现统一维护于 lib/。
source "${${(%):-%x}:A:h}/../../lib/command_runtime.sh"
