#!/bin/zsh
# filepath: tools/release/release.sh
# 仓库维护入口，不随 Formula 安装。
set -euo pipefail
REPO_ROOT="${0:A:h:h:h}"
source "$REPO_ROOT/lib/colors.sh"
source "$REPO_ROOT/lib/utils.sh"
source "$REPO_ROOT/bin/lib/cli_runtime.sh"
source "$REPO_ROOT/tools/release/lib/help_release.sh"
source "$REPO_ROOT/tools/release/lib/validators_release.sh"
source "$REPO_ROOT/tools/release/lib/forward_args.sh"
source "$REPO_ROOT/tools/release/lib/cli_dispatch_release.sh"
run_release_script() { run_zsh_script tools/release/publish.sh "$@"; }
handle_release "$@"
