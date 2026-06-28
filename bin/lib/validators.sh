#!/bin/zsh
# filepath: bin/lib/validators.sh

# shellcheck disable=SC1091
source "$REPO_ROOT/bin/lib/validators_setup.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/bin/lib/validators_maintain.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/bin/lib/validators_job.sh"
# shellcheck disable=SC1091
source "$REPO_ROOT/bin/lib/validators_release.sh"
