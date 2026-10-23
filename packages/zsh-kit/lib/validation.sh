#!/bin/zsh
# filepath: packages/zsh-kit/lib/validation.sh
# Pure validation: no filesystem access, logging callbacks or global mutation.
_sk_argument_error() { printf '参数无效: %s\n' "$*" >&2; return 2; }
_sk_bool() { [[ "$1" == true || "$1" == false ]] || _sk_argument_error '布尔值必须为 true 或 false'; }
_sk_required() { [[ -n "$1" ]] || _sk_argument_error '必填值不能为空'; }
_sk_line() { [[ -n "$1" && "$1" != *$'\n'* && "$1" != *$'\r'* ]] || _sk_argument_error '名称必须是非空单行文本'; }
_sk_uint() {
    [[ "$1" == <-> && ${#1} -le 10 ]] || { _sk_argument_error '必须为十进制整数'; return 2; }
    (( 10#$1 >= $2 && 10#$1 <= $3 )) || _sk_argument_error "整数范围为 $2–$3"
}
_sk_mode() { [[ -z "$1" || ( ${#1} -ge 3 && ${#1} -le 4 && "$1" != *[^0-7]* ) ]] || _sk_argument_error '权限必须为三或四位八进制数字'; }
