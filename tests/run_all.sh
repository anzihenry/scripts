#!/bin/zsh
# filepath: tests/run_all.sh
# Safe full regression runner. Actual installation/USB tests are separate.
set -euo pipefail
ROOT="${0:A:h:h}"
(( $# == 2 )) && [[ "$1" == --report && -n "$2" ]] || { print -u2 '用法: zsh tests/run_all.sh --report NEW_DIRECTORY'; exit 2; }
report="${2:A}"
[[ ! -e "$report" && ! -L "$2" ]] || { print -u2 '报告目录已存在，拒绝覆盖'; exit 2; }
mkdir -p "${report:h}"
mkdir "$report"
cd "$ROOT"
{
 print -r -- "utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
 print -r -- "commit=$(git rev-parse HEAD)"
 print -r -- "dirty=$(git status --porcelain | wc -l | tr -d ' ')"
 print 'scope=sandbox-regression; no real install/USB verification'
} > "$report/environment.txt"
finish() {
 local code=$?
 print -r -- "exit_code=$code" >> "$report/summary.txt"
 print -- "验证报告: $report"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
run_check() {
 local label="$1" code=0; shift
 print -- "运行: $label"
 "$@" > "$report/$label.log" 2>&1 || code=$?
 print -r -- "$label=$code" >> "$report/summary.txt"
 if (( code != 0 )); then tail -40 "$report/$label.log"; return "$code"; fi
}
run_check platform /bin/zsh tools/platform_identity.sh || exit $?
cat "$report/platform.log" >> "$report/environment.txt"
run_check bootstrap-sync /bin/zsh lint/sync_bootstrap.sh --check || exit $?
run_check syntax /bin/zsh tests/syntax_guard.sh || exit $?
run_check lint ./lint/lint_shell.sh || exit $?
run_check smoke ./tests/smoke_cli.sh || exit $?
for suite in bootstrap_guard cli_dispatch_guard cli_validators_guard version_consistency_guard regression_guard \
 zsh_migration_guard macos_installer_flow_guard release_publish_guard setup_runtime_guard maintain_runtime_guard \
 idempotence_guard reliability_guard homebrew_recovery_guard zsh_kit_guard template_guard reuse_acceptance_guard artifact_tools_guard platform_guard api_surface_guard package_release_guard; do
 run_check "$suite" /bin/zsh "tests/$suite.sh" || exit $?
done
run_check e2e /bin/zsh tests/e2e/run_all.sh || exit $?
print '全部沙箱回归通过'
