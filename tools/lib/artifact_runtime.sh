#!/bin/zsh
# filepath: tools/lib/artifact_runtime.sh
# Trusted tooling helper; never source code from the package being installed.
_artifact_lock() {
    local destination="$1" directory="/tmp/zsh-kit-artifacts-$EUID" timeout="${ZSH_KIT_TOOL_LOCK_TIMEOUT-30}"
    [[ "$timeout" == <-> && ${#timeout} -le 4 ]] || return 2
    [[ ! -L "$directory" ]] || return 1
    (umask 077; mkdir -p "$directory") || return 1
    [[ "$(stat -f '%u:%Lp' "$directory")" == "$EUID:700" ]] || return 1
    ARTIFACT_KEY="$(printf '%s' "$destination" | shasum -a 256)" || return 1
    ARTIFACT_KEY="${ARTIFACT_KEY%% *}"
    local lock_file="$directory/$ARTIFACT_KEY.lock"
    [[ ! -L "$lock_file" && ( ! -e "$lock_file" || -f "$lock_file" ) ]] || return 1
    (umask 077; : >> "$lock_file") || return 1
    zmodload zsh/system || return 1
    zsystem flock -t "$timeout" -f ARTIFACT_LOCK_FD "$lock_file" || { print -u2 '目标正在被其他生成/同步任务使用'; return 1; }
}
_artifact_recover() {
    local work="$1" destination="$2" validator="$3"
    [[ -e "$work" || -L "$work" ]] || return 0
    [[ ! -L "$work" && -d "$work" && "$(stat -f '%u:%Lp' "$work")" == "$EUID:700" ]] || return 1
    # A process may be killed between mkdir and writing its marker.
    if [[ ! -e "$work/.destination" ]]; then rmdir "$work"; return $?; fi
    [[ ! -L "$work/.destination" && "$(cat "$work/.destination")" == "$destination" ]] || return 1
    if [[ -e "$work/previous" || -L "$work/previous" ]]; then
        [[ ! -L "$work/previous" && -d "$work/previous" ]] || return 1
        if [[ ! -e "$destination" && ! -L "$destination" ]]; then
            mv "$work/previous" "$destination" || { print -u2 "恢复失败，保留原件: $work/previous"; return 1; }
        elif ! "$validator" "$destination"; then
            print -u2 "目标异常，原件保留在 $work/previous；请人工检查。"
            return 1
        fi
    fi
    rm -rf "$work"
}
_artifact_begin() {
    local destination="$1" validator="$2"
    ARTIFACT_WORK="${destination:h}/.zsh-kit-transaction-$ARTIFACT_KEY"
    _artifact_recover "$ARTIFACT_WORK" "$destination" "$validator" || return 1
    (umask 077; mkdir "$ARTIFACT_WORK") || return 1
    printf '%s\n' "$destination" > "$ARTIFACT_WORK/.destination"
}
