#!/bin/zsh
# filepath: lint/sync_bootstrap.sh
# 从公共库生成独立 bootstrap 内嵌片段；--check 仅检查是否同步。
set -euo pipefail
ROOT="${0:A:h:h}"
CHECK=false
case "${1:-}" in --check) CHECK=true ;; '') ;; *) print -u2 '用法: zsh lint/sync_bootstrap.sh [--check]'; exit 2 ;; esac
temporary="$(mktemp -d "${TMPDIR:-/tmp}/bootstrap-sync.XXXXXXXX")"
trap 'rm -rf "$temporary"' EXIT
cp "$ROOT/bootstrap/install.sh" "$temporary/install.sh"

sync_region() {
    local marker="$1" source_file="$2" whole="$3"
    if [[ "$whole" == true ]]; then
        sed '1,2d' "$source_file" > "$temporary/region"
    else
        awk -v begin="# BEGIN $marker" -v end="# END $marker" '$0==begin {active=1;next} $0==end {exit} active {print}' "$source_file" > "$temporary/region"
    fi
    [[ -s "$temporary/region" ]] || { print -u2 "缺少源片段: $marker"; return 1; }
    awk -v begin="# BEGIN $marker" -v end="# END $marker" -v region="$temporary/region" '
      $0==begin {if (active || count++) exit 1; active=1; print; while ((getline line < region)>0) print line; close(region); next}
      $0==end {if (!active) exit 1; active=0; ends++; print; next}
      !active {print}
      END {if (active || count!=1 || ends!=1) exit 1}
    ' "$temporary/install.sh" > "$temporary/next" || return 1
    mv "$temporary/next" "$temporary/install.sh"
}

# Standalone bundles contain definitions plus application adapters, with no repo imports.
{ print '#!/bin/zsh'; print '# generated bundle'; sed '1,2d' "$ROOT/packages/zsh-kit/lib/logging.sh"; sed -n '/# BEGIN APP ADAPTER/,/# END APP ADAPTER/p' "$ROOT/lib/logging.sh"; } > "$temporary/logging.sh"
{ print '#!/bin/zsh'; print '# generated bundle'; sed '1,2d' "$ROOT/packages/zsh-kit/lib/console.sh"; sed '1,2d; /^source /d' "$ROOT/packages/zsh-kit/lib/resource_lock.sh"; sed -n '/# BEGIN APP ADAPTER/,/# END APP ADAPTER/p' "$ROOT/lib/resource_lock.sh"; } > "$temporary/resource_lock.sh"
sync_region 'STANDALONE LOGGING' "$temporary/logging.sh" true
sync_region 'MACOS REQUIREMENT' "$ROOT/lib/utils.sh" false
sync_region 'FIRST LINE' "$ROOT/lib/utils.sh" false
sync_region 'RESOURCE LOCK' "$temporary/resource_lock.sh" true
/bin/zsh -n "$temporary/install.sh"
if cmp -s "$temporary/install.sh" "$ROOT/bootstrap/install.sh"; then
    print 'Bootstrap 内嵌公共代码已同步。'
elif [[ "$CHECK" == true ]]; then
    print -u2 'Bootstrap 内嵌代码未同步，请运行 zsh lint/sync_bootstrap.sh。'
    exit 1
else
    cat "$temporary/install.sh" > "$ROOT/bootstrap/install.sh"
    print '已同步 Bootstrap 内嵌公共代码。'
fi
