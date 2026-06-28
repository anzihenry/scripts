#!/bin/zsh
# filepath: tests/cli_validators_guard.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS_COUNT=0
MACOS_SCRIPTS_VERSION="0.3.0"

pass() {
  printf '[PASS] %s\n' "$1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
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

error() {
  printf 'ERROR:%s\n' "$*" >&2
}

# shellcheck disable=SC1091
source "$REPO_ROOT/bin/lib/help.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/bin/lib/cli_runtime.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/bin/lib/validators.sh"

run_expect_failure_contains() {
  local name="$1"
  local pattern="$2"
  shift 2
  local output=""

  set +e
  output="$("$@" 2>&1)"
  local exit_code=$?
  set -e

  [[ $exit_code -ne 0 ]] || {
    printf '%s\n' "$output" >&2
    fail "$name"
  }

  assert_contains "$output" "$pattern" "$name"
}

run_expect_success_contains() {
  local name="$1"
  local pattern="$2"
  shift 2
  local output=""

  output="$("$@" 2>&1)" || {
    printf '%s\n' "$output" >&2
    fail "$name"
  }

  assert_contains "$output" "$pattern" "$name"
}

test_validator_failures() {
  run_expect_failure_contains \
    "setup brew configure rejects unsupported arg" \
    "setup brew configure 不支持参数: --bogus" \
    validate_setup_brew_configure_args --bogus

  run_expect_failure_contains \
    "setup github rejects domain override in validator" \
    "setup github 固定使用 github.com" \
    validate_setup_github_args --domain example.com

  run_expect_failure_contains \
    "maintain brew rejects unsupported arg" \
    "maintain brew 不支持参数: --bogus" \
    validate_maintain_brew_args --bogus

  run_expect_failure_contains \
    "installer download requires version value" \
    "--version 需要一个参数值" \
    validate_installer_download_args --version

  run_expect_failure_contains \
    "installer create requires volume value" \
    "--volume 需要一个参数值" \
    validate_installer_create_args --volume

  run_expect_failure_contains \
    "release publish requires tag" \
    "release publish 需要提供版本 tag" \
    validate_release_publish_args --notes-file notes.md

  run_expect_failure_contains \
    "release verify rejects unsupported arg" \
    "release verify 不支持参数: --bogus" \
    validate_release_verify_args v0.3.0 --bogus

  run_expect_failure_contains \
    "job status requires job name" \
    "job status 需要提供 --job-name" \
    validate_job_name_action_args status print_job_status_help false

  run_expect_failure_contains \
    "job create rejects weekday without at" \
    "--weekday 需要配合 --at 使用" \
    validate_job_create_args --job-name demo --script ./lint/lint_shell.sh --interval 5 --weekday 1

  run_expect_failure_contains \
    "job create rejects weekday out of range" \
    "--weekday 取值范围为 0-6" \
    validate_job_create_args --job-name demo --script ./lint/lint_shell.sh --at 12:00 --weekday 7
}

test_help_topics() {
  run_expect_success_contains \
    "help setup topic stays consistent" \
    "macos-scripts setup shell" \
    handle_help setup

  run_expect_success_contains \
    "help maintain installer topic stays consistent" \
    "macos-scripts maintain installer download" \
    handle_help maintain installer

  run_expect_success_contains \
    "help release topic stays consistent" \
    "macos-scripts release publish" \
    handle_help release

  run_expect_success_contains \
    "help job create topic documents schedule args" \
    "--interval <分钟>" \
    handle_help job create
}

main() {
  cd "$REPO_ROOT"
  test_validator_failures
  test_help_topics
  printf '\nCLI validator guard passed: %d\n' "$PASS_COUNT"
}

main "$@"
