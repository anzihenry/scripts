#!/bin/zsh
# filepath: setup/lib/homebrew_recovery.sh
# 持久化边界检查点。日志只作为数据读取，不 source/eval。
homebrew_file_identity() {
    local file="$1" digest
    [[ ! -L "$file" ]] || return 1
    if [[ ! -e "$file" ]]; then print -r -- missing; return 0; fi
    [[ -f "$file" ]] || return 1
    digest="$(shasum -a 256 "$file")" || return 1
    print -r -- "${digest%% *}:$(stat -f '%Lp' "$file")"
}

homebrew_journal_state() {
    printf '%s\n' "$1" > "$HBC_BACKUP_DIR/state.new" &&
        mv -f "$HBC_BACKUP_DIR/state.new" "$HBC_BACKUP_DIR/state"
}

homebrew_journal_checkpoint() {
    local index identity
    for ((index=1; index<=${#HBC_TARGETS}; index++)); do
        identity="$(homebrew_file_identity "${HBC_TARGETS[index]}")" || return 1
        printf '%s\n' "$identity" > "$HBC_BACKUP_DIR/$index.expected.new" || return 1
        mv -f "$HBC_BACKUP_DIR/$index.expected.new" "$HBC_BACKUP_DIR/$index.expected" || return 1
    done
}

homebrew_transaction_step() {
    local code=0
    "$@" || code=$?
    homebrew_journal_checkpoint || return 1
    return "$code"
}

homebrew_journal_begin() {
    local index identity
    printf '%s\n' "$HBC_SCOPE" > "$HBC_BACKUP_DIR/scope" || return 1
    for ((index=1; index<=${#HBC_TARGETS}; index++)); do
        identity=missing
        if [[ "${HBC_EXISTED[index]}" == 1 ]]; then
            identity="$(homebrew_file_identity "$HBC_BACKUP_DIR/$index")" || return 1
        fi
        printf '%s\n' "$identity" > "$HBC_BACKUP_DIR/$index.original" || return 1
    done
    homebrew_journal_checkpoint || return 1
    homebrew_journal_state active
}

homebrew_recover_pending() (
    local backup_root="$1" journal recorded_state index existed target original current expected
    local -a HBC_TARGETS HBC_EXISTED
    local HBC_BACKUP_DIR
    for journal in "$backup_root"/homebrew-config.*(N/); do
        [[ ! -L "$journal" && "$(stat -f '%u:%Lp' "$journal")" == "$EUID:700" ]] || return 1
        [[ -f "$journal/state" ]] || continue # 旧备份或未开始修改的准备目录。
        [[ ! -L "$journal/state" && ! -L "$journal/scope" && -f "$journal/scope" ]] || return 1
        [[ "$(cat "$journal/scope")" == "$HBC_SCOPE" ]] || continue
        recorded_state="$(cat "$journal/state")"
        case "$recorded_state" in
            committed) rm -rf "$journal" || return 1; continue ;;
            rolled-back) continue ;;
            active) ;;
            *) error "事务状态损坏，请检查备份: $journal"; return 1 ;;
        esac
        [[ -f "$journal/manifest.tsv" && ! -L "$journal/manifest.tsv" ]] || return 1
        HBC_TARGETS=() HBC_EXISTED=()
        while IFS=$'\t' read -r index existed target; do
            [[ "$index" == $((${#HBC_TARGETS}+1)) && ( "$existed" == 0 || "$existed" == 1 ) ]] || return 1
            [[ -n "$target" && ${HBC_ALLOWED_TARGETS[(Ie)$target]} != 0 && ${HBC_TARGETS[(Ie)$target]} == 0 ]] || return 1
            resource_lock_acquire "$target" || return 1
            [[ -f "$journal/$index.original" && ! -L "$journal/$index.original" && -f "$journal/$index.expected" && ! -L "$journal/$index.expected" ]] || return 1
            original="$(cat "$journal/$index.original")"
            expected="$(cat "$journal/$index.expected")"
            if [[ "$existed" == 1 ]]; then
                [[ -f "$journal/$index" && "$(homebrew_file_identity "$journal/$index")" == "$original" ]] || { error "备份损坏，未恢复: $journal"; return 1; }
            else
                [[ "$original" == missing ]] || return 1
            fi
            current="$(homebrew_file_identity "$target")" || return 1
            if [[ "$current" != "$original" && "$current" != "$expected" ]]; then
                error "发现事务后续修改或未记录的写入，未自动覆盖: $target；请核对备份 $journal 后手动恢复，并将 state 标记为 rolled-back 再重试。"
                return 1
            fi
            HBC_TARGETS+=("$target") HBC_EXISTED+=("$existed")
        done < "$journal/manifest.tsv"
        (( ${#HBC_TARGETS} == ${#HBC_ALLOWED_TARGETS} )) || { error "事务目标发生变化，保留备份: $journal"; return 1; }
        HBC_BACKUP_DIR="$journal"
        homebrew_restore_snapshot || { error "中断事务恢复失败，请保留备份: $journal"; return 1; }
        homebrew_journal_state rolled-back || return 1
        warning "已恢复上次中断的 Homebrew 配置；备份保留: $journal"
    done
)
