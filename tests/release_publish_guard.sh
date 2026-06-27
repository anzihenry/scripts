#!/bin/bash
# filepath: tests/release_publish_guard.sh

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

assert_eq() {
  local actual="$1"
  local expected="$2"
  local name="$3"

  if [[ "$actual" != "$expected" ]]; then
    printf 'expected: %s\nactual:   %s\n' "$expected" "$actual" >&2
    fail "$name"
  fi

  pass "$name"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local name="$3"

  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'missing substring: %s\noutput: %s\n' "$needle" "$haystack" >&2
    fail "$name"
  fi

  pass "$name"
}

info() { printf 'INFO:%s\n' "$*"; }
warning() { printf 'WARN:%s\n' "$*"; }
error() { printf 'ERROR:%s\n' "$*" >&2; }
success() { printf 'SUCCESS:%s\n' "$*"; }
print_header() { printf 'HEADER:%s\n' "$1"; }

# shellcheck disable=SC1091
source "$REPO_ROOT/maintain/lib/release_publish_flow.sh"

test_confirm_publish_short_circuit() {
  YES="false"
  DRY_RUN="true"
  VERIFY_ONLY="false"
  REPO_SLUG="anzihenry/scripts"
  confirm_publish
  pass "confirm_publish skips prompt in dry-run"

  DRY_RUN="false"
  VERIFY_ONLY="true"
  confirm_publish
  pass "confirm_publish skips prompt in verify-only"

  VERIFY_ONLY="false"
  YES="true"
  confirm_publish
  pass "confirm_publish skips prompt with --yes"
}

test_create_release_path() {
  local recorded_description=""
  local recorded_command=""
  local output_file=""
  local output=""
  output_file="$(mktemp "${TMPDIR:-/tmp}/release-publish-guard.XXXXXX")"

  release_exists() { return 1; }
  run_logged_command() {
    recorded_description="$1"
    shift
    recorded_command="$*"
  }

  TAG="v1.2.3"
  REPO_SLUG="anzihenry/scripts"
  TITLE="Release 1.2.3"
  TARGET="main"
  NOTES_FILE="/tmp/release-notes.md"
  UPDATE_EXISTING="false"

  create_or_update_release > "$output_file"
  output="$(cat "$output_file")"
  rm -f "$output_file"
  assert_contains "$output" "HEADER:执行 GitHub Release" "create path prints header"
  assert_eq "$recorded_description" "创建 GitHub Release: $TAG" "create path uses create description"
  assert_eq "$recorded_command" "gh release create $TAG --repo $REPO_SLUG --title $TITLE --target $TARGET --notes-file $NOTES_FILE" "create path forwards create command"
}

test_update_release_path() {
  local recorded_description=""
  local recorded_command=""

  release_exists() { return 0; }
  run_logged_command() {
    recorded_description="$1"
    shift
    recorded_command="$*"
  }

  TAG="v1.2.3"
  REPO_SLUG="anzihenry/scripts"
  TITLE="Release 1.2.3"
  NOTES_FILE="/tmp/release-notes.md"
  UPDATE_EXISTING="true"

  create_or_update_release > /dev/null
  assert_eq "$recorded_description" "更新 GitHub Release: $TAG" "update path uses edit description"
  assert_eq "$recorded_command" "gh release edit $TAG --repo $REPO_SLUG --title $TITLE --notes-file $NOTES_FILE" "update path forwards edit command"
}

test_verify_release_dry_run() {
  local output=""

  DRY_RUN="true"
  TAG="v1.2.3"
  output="$(verify_release)"
  assert_contains "$output" "HEADER:发布结果" "verify release prints header"
  assert_contains "$output" "INFO:dry-run 模式未实际创建 release" "verify release reports dry-run"
}

main() {
  cd "$REPO_ROOT"

  test_confirm_publish_short_circuit
  test_create_release_path
  test_update_release_path
  test_verify_release_dry_run

  printf '\nRelease publish guard passed: %d\n' "$PASS_COUNT"
}

main "$@"
