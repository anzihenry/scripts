#!/bin/zsh
# filepath: tests/reuse_acceptance_guard.sh
set -euo pipefail
ROOT="${0:A:h:h}"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/reuse acceptance.XXXXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
cp -R "$ROOT/examples/file-organizer" "$SANDBOX/standalone project"
project="$SANDBOX/standalone project"
cp "$ROOT/tools/vendor_zsh_kit.sh" "$project/scripts/"
mkdir -p "$project/scripts/lib"
cp -R "$ROOT/tools/lib/." "$project/scripts/lib/"
# Run from an unrelated cwd with only system tools; no repository/application imports.
(cd "$SANDBOX"; PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/zsh "$project/tests/run.sh")
business_before="$(shasum -a 256 "$project"/src/*.sh "$project"/bin/*)"
cp -R "$ROOT/packages/zsh-kit" "$SANDBOX/patch-fixture"
# This is a synthetic compatibility fixture, NOT a published component release.
base_version="$(cat "$ROOT/packages/zsh-kit/VERSION")"
fixture_version="${base_version%.*}.$((${base_version##*.} + 1))"
print -r -- "$fixture_version" > "$SANDBOX/patch-fixture/VERSION"
cat >> "$SANDBOX/patch-fixture/lib/console.sh" <<'PATCH'
# Private fixture marker; public compatibility is checked by the frozen consumer.
_sk_fixture_capability() { printf '%s\n' compatible-patch; }
PATCH
result=0
/bin/zsh "$project/scripts/vendor_zsh_kit.sh" --diff "$SANDBOX/patch-fixture" "$project/vendor/zsh-kit" > "$SANDBOX/upgrade.diff" || result=$?
[[ "$result" == 1 && -s "$SANDBOX/upgrade.diff" ]]
/bin/zsh "$project/scripts/vendor_zsh_kit.sh" --sync "$SANDBOX/patch-fixture" "$project/vendor/zsh-kit"
sed "s/^APP_KIT_VERSION=.*/APP_KIT_VERSION=$fixture_version/" "$project/project.conf" > "$SANDBOX/project.conf"
mv "$SANDBOX/project.conf" "$project/project.conf"
[[ "$business_before" == "$(shasum -a 256 "$project"/src/*.sh "$project"/bin/*)" ]]
# New processes see the new API; existing public functions retain their behavior.
[[ "$(/bin/zsh -c 'source "$1/lib/zsh-kit.sh"; _sk_fixture_capability' zsh "$project/vendor/zsh-kit")" == compatible-patch ]]
rm -rf "$SANDBOX/patch-fixture"
(cd "$SANDBOX"; PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/zsh "$project/tests/run.sh")
print -- "Reuse acceptance passed: independent app, unchanged business code, synthetic $fixture_version upgrade"
