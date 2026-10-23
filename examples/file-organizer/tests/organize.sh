#!/bin/zsh
# filepath: tests/organize.sh
set -euo pipefail
ROOT="${0:A:h:h}"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/organizer-test.XXXXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home" FILE_ORGANIZER_LOG_DIR="$SANDBOX/logs"
mkdir "$HOME" "$SANDBOX/files with spaces"
directory="$SANDBOX/files with spaces"
command_path="$ROOT/bin/file-organizer"
print document > "$directory/a note.txt"
print image > "$directory/picture.jpg"
print binary > "$directory/data.bin"
ln -s "$directory/data.bin" "$directory/link.txt"
/bin/zsh "$command_path" organize "$directory" --dry-run > "$SANDBOX/plan"
[[ ! -d "$directory/organized" && ! -d "$FILE_ORGANIZER_LOG_DIR" && -s "$SANDBOX/plan" ]]
/bin/zsh "$command_path" organize "$directory" >/dev/null
[[ -f "$directory/organized/documents/a note.txt" && -f "$directory/organized/images/picture.jpg" && -f "$directory/organized/other/data.bin" && -L "$directory/link.txt" ]]
before="$(stat -f '%i:%m' "$directory/organized/documents/a note.txt")"
/bin/zsh "$command_path" organize "$directory" >/dev/null
[[ "$before" == "$(stat -f '%i:%m' "$directory/organized/documents/a note.txt")" ]]
# Name conflict must not overwrite either version or move other files.
print new > "$directory/a note.txt"
print waiting > "$directory/z.txt"
/bin/zsh "$command_path" organize "$directory" >/dev/null 2>&1 && exit 1
[[ "$(cat "$directory/a note.txt")" == new && "$(cat "$directory/organized/documents/a note.txt")" == document && -f "$directory/z.txt" ]]
mv "$directory/a note.txt" "$directory/renamed.txt"
/bin/zsh "$command_path" organize "$directory" >/dev/null
[[ -f "$directory/organized/documents/renamed.txt" && -f "$directory/organized/documents/z.txt" ]]
# Inject a real command failure after one successful move, then retry normally.
mkdir "$SANDBOX/failure" "$SANDBOX/shims"
print a > "$SANDBOX/failure/a.txt"; print b > "$SANDBOX/failure/b.txt"
cat > "$SANDBOX/shims/mv" <<'SHIM'
#!/bin/zsh
if [[ "${2:t}" == b.txt ]]; then exit 9; fi
exec /bin/mv "$@"
SHIM
chmod +x "$SANDBOX/shims/mv"
PATH="$SANDBOX/shims:$PATH" /bin/zsh "$command_path" organize "$SANDBOX/failure" >/dev/null 2>&1 && exit 1
[[ -f "$SANDBOX/failure/organized/documents/a.txt" && -f "$SANDBOX/failure/b.txt" ]]
/bin/zsh "$command_path" organize "$SANDBOX/failure" >/dev/null
[[ -f "$SANDBOX/failure/organized/documents/b.txt" && ! -f "$SANDBOX/failure/b.txt" ]]
mkdir "$SANDBOX/unsafe" "$SANDBOX/outside"
print x > "$SANDBOX/unsafe/file.txt"
ln -s "$SANDBOX/outside" "$SANDBOX/unsafe/organized"
/bin/zsh "$command_path" organize "$SANDBOX/unsafe" >/dev/null 2>&1 && exit 1
[[ -f "$SANDBOX/unsafe/file.txt" && -z "$(ls -A "$SANDBOX/outside")" ]]
print 'File organizer tests passed'
