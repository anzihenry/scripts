#!/bin/zsh
# filepath: setup/lib/config_writer.sh
# 兼容旧导入路径；实现统一维护于 lib/。
source "${${(%):-%x}:A:h}/../../lib/config_writer.sh"
