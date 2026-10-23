#!/bin/zsh
# filepath: packages/zsh-kit/lib/resource_lock.sh
# 同步调用链可重入的资源锁。锁文件永久保留，禁止删除/替换正在使用的 inode。
# 获取顺序：业务运行锁 -> Homebrew 实例 -> 配置文件。不可并行派生共享事务。
source "${${(%):-%x}:A:h}/console.sh"

sk_resource_lock_acquire() {
    (( $# == 1 )) || return 2
    _sk_required "$1" || return 2
    _sk_uint "${SK_LOCK_TIMEOUT-10}" 0 9999 || return 2
    typeset -ga SK_RESOURCE_LOCKS SK_RESOURCE_FDS SK_RESOURCE_OWNERS
    local resource="$1" key lock_file lock_fd
    # 不随 CONFIG_DIR/TMPDIR 改变，保证不同入口仍协调同一真实资源。
    local directory="/tmp/macos-scripts-locks-$EUID"
    local timeout="${SK_LOCK_TIMEOUT:-10}"
    [[ "$resource" != /* ]] || resource="${resource:A}"
    (( ${SK_RESOURCE_LOCKS[(Ie)$resource]} == 0 )) || return 0
    [[ "$timeout" == <-> && ${#timeout} -le 4 ]] || { sk_error "锁等待时间必须为 0–9999 秒"; return 1; }
    [[ ! -L "$directory" ]] || { sk_error "锁目录不能是符号链接: $directory"; return 1; }
    (umask 077; mkdir -p "$directory") || return 1
    [[ "$(stat -f '%u:%Lp' "$directory")" == "$EUID:700" ]] || { sk_error "锁目录所有者或权限异常: $directory"; return 1; }
    key="$(printf '%s' "$resource" | shasum -a 256)" || return 1
    lock_file="$directory/${key%% *}.lock"
    [[ ! -L "$lock_file" && ( ! -e "$lock_file" || -f "$lock_file" ) ]] || return 1
    # 用子进程创建，避免在当前进程重新打开已持有的 fcntl 锁文件。
    (umask 077; : >> "$lock_file") || return 1
    zmodload zsh/system || return 1
    if ! zsystem flock -t "$timeout" -i 0.1 -f lock_fd "$lock_file"; then
        sk_error "资源正在使用或无法加锁: $resource；等待其他操作完成后重试。"
        return 1
    fi
    SK_RESOURCE_LOCKS+=("$resource")
    SK_RESOURCE_FDS+=("$lock_fd")
    SK_RESOURCE_OWNERS+=("$sysparams[pid]")
}

sk_with_resource_lock() (
    (( $# >= 2 )) || return 2
    _sk_required "$1" && _sk_required "$2" || return 2
    _sk_uint "${SK_LOCK_TIMEOUT-10}" 0 9999 || return 2
    local resource="$1"
    shift
    sk_resource_lock_acquire "$resource" || return $?
    "$@"
)



# 仅释放当前进程获取的锁，不能释放父事务的锁。
sk_resource_locks_release_owned() {
    (( $# == 0 )) || return 2
    zmodload zsh/system || return 1
    typeset -ga SK_RESOURCE_LOCKS SK_RESOURCE_FDS SK_RESOURCE_OWNERS
    local index
    for ((index=${#SK_RESOURCE_LOCKS}; index>=1; index--)); do
        [[ "${SK_RESOURCE_OWNERS[index]}" == "$sysparams[pid]" ]] || continue
        zsystem flock -u "${SK_RESOURCE_FDS[index]}" || return 1
        SK_RESOURCE_LOCKS[index]=()
        SK_RESOURCE_FDS[index]=()
        SK_RESOURCE_OWNERS[index]=()
    done
}
