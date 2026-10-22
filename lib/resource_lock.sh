#!/bin/zsh
# filepath: lib/resource_lock.sh
# 同步调用链可重入的资源锁。锁文件永久保留，禁止删除/替换正在使用的 inode。
# 获取顺序：业务运行锁 -> Homebrew 实例 -> 配置文件。不可并行派生共享事务。
typeset -ga MS_RESOURCE_LOCKS MS_RESOURCE_FDS MS_RESOURCE_OWNERS

resource_lock_acquire() {
    local resource="$1" key lock_file lock_fd
    # 不随 CONFIG_DIR/TMPDIR 改变，保证不同入口仍协调同一真实资源。
    local directory="/tmp/macos-scripts-locks-$EUID"
    local timeout="${MACOS_SCRIPTS_LOCK_TIMEOUT:-10}"
    [[ "$resource" != /* ]] || resource="${resource:A}"
    (( ${MS_RESOURCE_LOCKS[(Ie)$resource]} == 0 )) || return 0
    [[ "$timeout" == <-> && ${#timeout} -le 4 ]] || { error "锁等待时间必须为 0–9999 秒"; return 1; }
    [[ ! -L "$directory" ]] || { error "锁目录不能是符号链接: $directory"; return 1; }
    (umask 077; mkdir -p "$directory") || return 1
    [[ "$(stat -f '%u:%Lp' "$directory")" == "$EUID:700" ]] || { error "锁目录所有者或权限异常: $directory"; return 1; }
    key="$(printf '%s' "$resource" | shasum -a 256)" || return 1
    lock_file="$directory/${key%% *}.lock"
    [[ ! -L "$lock_file" && ( ! -e "$lock_file" || -f "$lock_file" ) ]] || return 1
    # 用子进程创建，避免在当前进程重新打开已持有的 fcntl 锁文件。
    (umask 077; : >> "$lock_file") || return 1
    zmodload zsh/system || return 1
    if ! zsystem flock -t "$timeout" -i 0.1 -f lock_fd "$lock_file"; then
        error "资源正在使用或无法加锁: $resource；等待其他操作完成后重试。"
        return 1
    fi
    MS_RESOURCE_LOCKS+=("$resource")
    MS_RESOURCE_FDS+=("$lock_fd")
    MS_RESOURCE_OWNERS+=("$sysparams[pid]")
}

with_resource_lock() (
    local resource="$1"
    shift
    resource_lock_acquire "$resource" || return 1
    "$@"
)

homebrew_resource_lock() {
    local brew_bin="${1:-}" prefix
    [[ -n "$brew_bin" ]] || brew_bin="$(resolve_homebrew_bin)" || return 1
    prefix="$("$brew_bin" --prefix)" || return 1
    [[ -n "$prefix" && "$prefix" == /* ]] || { error "Homebrew prefix 无效"; return 1; }
    resource_lock_acquire "${prefix:A}/.macos-scripts-resource"
}

# 仅释放当前进程获取的锁，不能释放父事务的锁。
resource_locks_release_owned() {
    zmodload zsh/system || return 1
    local index
    for ((index=${#MS_RESOURCE_LOCKS}; index>=1; index--)); do
        [[ "${MS_RESOURCE_OWNERS[index]}" == "$sysparams[pid]" ]] || continue
        zsystem flock -u "${MS_RESOURCE_FDS[index]}" || return 1
        MS_RESOURCE_LOCKS[index]=()
        MS_RESOURCE_FDS[index]=()
        MS_RESOURCE_OWNERS[index]=()
    done
}
