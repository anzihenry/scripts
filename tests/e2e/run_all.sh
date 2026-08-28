#!/bin/bash
# filepath: tests/e2e/run_all.sh
# E2E 汇总运行器：顺序执行 tests/e2e/ 下所有用例，聚合结果。
# 任一个用例失败时整体返回非零，便于接入 CI 与发布门禁。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CASES=(
  job_create
  job_list
  job_disable
  release_verify
  release_publish
  maintain_brew
  setup_brew_configure
  bootstrap_install
)

TOTAL_PASS=0
TOTAL_FAIL=0

cd "$REPO_ROOT"

for case in "${CASES[@]}"; do
  printf '\n===== E2E: %s =====\n' "$case"
  if bash "$SCRIPT_DIR/$case.sh"; then
    TOTAL_PASS=$((TOTAL_PASS + 1))
  else
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
  fi
done

printf '\n===== E2E 汇总: 通过 %d, 失败 %d =====\n' "$TOTAL_PASS" "$TOTAL_FAIL"
[[ "$TOTAL_FAIL" -eq 0 ]]
