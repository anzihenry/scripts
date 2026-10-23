#!/bin/zsh
# filepath: packages/zsh-kit/tests/consumer.sh
# Frozen consumer behavior; runs unchanged against the old vendored and new source package.
set -euo pipefail
(( $# == 1 )) || exit 2
source "$1/lib/zsh-kit.sh"
sandbox="$(mktemp -d "${TMPDIR:-/tmp}/kit-consumer.XXXXXXXX")"
trap 'rm -rf "$sandbox"' EXIT
sk_write_managed_file "$sandbox/config" initial
sk_write_managed_block "$sandbox/config" settings consumer 'export EXAMPLE=yes'
sk_write_managed_block "$sandbox/config" settings consumer 'export EXAMPLE=yes'
cat "$sandbox/config"
sk_set_ini_values "$sandbox/tool.ini" settings name example enabled yes
cat "$sandbox/tool.ini"
fail_action() { return 7; }
code=0; sk_run_command fail_action || code=$?
printf 'command_exit=%s\n' "$code"
SK_DRY_RUN=true sk_run_command touch "$sandbox/not-created" >/dev/null
[[ ! -e "$sandbox/not-created" ]]
code=0; sk_run_stages first fail_action never true >/dev/null 2>&1 || code=$?
printf 'stage_exit=%s\n' "$code"
