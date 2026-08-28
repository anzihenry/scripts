#!/bin/zsh
# filepath: tests/version_consistency_guard.sh
# 回归护栏：VERSION 权威文件与各处 fallback / 引用版本保持一致。
# 防止发布新版本时只改 VERSION，而遗漏同步：
#   - bin/macos-scripts 的 fallback 版本
#   - bootstrap/install.sh 的 fallback 版本
#   - Formula/macos-scripts.rb 引用的 tag 版本
#   - releases/v<version>-release-notes.md 文件
# 纯本地只读检查，不依赖 gh / tag / 网络，可在普通 PR 的 CI 中执行。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS_COUNT=0

pass() {
  printf '[PASS] %s\n' "$1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

# 从文件提取版本号；无匹配时输出空串（不因 grep 非零退出）。
extract_version() {
  local file="$1"
  local pattern="$2"
  grep -oE "$pattern" "$file" 2>/dev/null | head -1 || true
}

main() {
  cd "$REPO_ROOT"

  local expected=""
  expected="$(<"$REPO_ROOT/VERSION")"
  [[ -n "$expected" ]] || fail "VERSION 文件为空"

  # 1. bin/macos-scripts 的 fallback 版本
  local entry_fallback=""
  entry_fallback="$(extract_version "$REPO_ROOT/bin/macos-scripts" 'MACOS_SCRIPTS_VERSION="[0-9]+\.[0-9]+\.[0-9]+"' | sed 's/.*"\([0-9.]*\)"/\1/')"
  if [[ -z "$entry_fallback" ]]; then
    fail "bin/macos-scripts 中未找到 fallback 版本"
  fi
  [[ "$entry_fallback" == "$expected" ]] \
    && pass "bin/macos-scripts fallback 与 VERSION 一致 ($expected)" \
    || fail "bin/macos-scripts fallback=$entry_fallback != VERSION=$expected"

  # 2. bootstrap/install.sh 的 fallback 版本
  local bootstrap_fallback=""
  bootstrap_fallback="$(extract_version "$REPO_ROOT/bootstrap/install.sh" 'FORMULA_STABLE_VERSION:-\$?\{?[0-9]+\.[0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
  if [[ -z "$bootstrap_fallback" ]]; then
    fail "bootstrap/install.sh 中未找到 fallback 版本"
  fi
  [[ "$bootstrap_fallback" == "$expected" ]] \
    && pass "bootstrap/install.sh fallback 与 VERSION 一致 ($expected)" \
    || fail "bootstrap/install.sh fallback=$bootstrap_fallback != VERSION=$expected"

  # 3. Formula/macos-scripts.rb 引用的 tag 版本（与 validators_release.sh 的提取口径一致）
  local formula_version=""
  formula_version="$(extract_version "$REPO_ROOT/Formula/macos-scripts.rb" 'refs/tags/v[0-9]+\.[0-9]+\.[0-9]+' | sed 's#refs/tags/v##')"
  if [[ -z "$formula_version" ]]; then
    fail "Formula/macos-scripts.rb 中未找到 tag 引用"
  fi
  [[ "$formula_version" == "$expected" ]] \
    && pass "Formula 引用 tag 与 VERSION 一致 (v$expected)" \
    || fail "Formula 引用=$formula_version != VERSION=$expected"

  # 4. 对应版本 release notes 文件存在（发布流程依赖）
  local notes_file="$REPO_ROOT/releases/v${expected}-release-notes.md"
  [[ -f "$notes_file" ]] \
    && pass "release notes 存在: releases/v${expected}-release-notes.md" \
    || fail "缺少 release notes 文件: $notes_file"

  printf '\nVersion consistency guard passed: %d\n' "$PASS_COUNT"
}

main "$@"
