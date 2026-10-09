---
title: 0.1.0 release and validation record
status: planned
owner: project-maintainers
updated: 2026-10-10
---

# v0.1.0 release checklist

[中文](validation.md)

Translation of the Chinese primary version. Commands and historical log excerpts retain their original language where applicable.

> Migrated historical material. Official publication status/time and candidate commit remain unverified. A checklist is not acceptance evidence. See the [current releasing guide](../../guides/releasing.en.md).

## Release goal

Version 0.1.0, tag v0.1.0, branch main. Scope matches the [version description](README.en.md).

## Before release

Review the worktree and exclude temporary changes. Align CLI and bootstrap version defaults with v0.1.0; ensure README/bootstrap/release examples and notes match. Remove user-facing main-branch bootstrap URLs. For 0.1.0, verify Formula caveats and stable URL/checksum refer to the release archive.

## Historical command sequence

Commands below reproduce the Chinese checklist's historical examples. Run from the repository root only in the corresponding release context; use the current guide for new releases. Commands select Chinese notes by default; an English publication can explicitly select README.en.md.

### Pre-release checks

```bash
./bin/macos-scripts --version
zsh bootstrap/install.sh --dry-run --yes --skip-configure
zsh lint/lint_shell.sh bootstrap/install.sh bin/macos-scripts setup maintain job lint
zsh -n bootstrap/install.sh setup/*.sh maintain/*.sh job/*.sh lint/*.sh bin/macos-scripts
bash -n lib/colors.sh setup/git_forge_ssh_setup.sh
```

### Local installation rehearsal

```bash
cat >/tmp/macos-scripts-install-test.sh <<'EOF'
#!/bin/zsh
set -e
set -u
set -o pipefail

WORKSPACE="/absolute/path/to/scripts"
TMPDIR_ROOT="$(mktemp -d)"

cleanup() {
  set +e
  if brew list --formula macos-scripts >/dev/null 2>&1; then
    HOMEBREW_NO_AUTO_UPDATE=1 brew uninstall --formula macos-scripts >/dev/null 2>&1 || true
  fi
  if brew tap | grep -qx 'anzihenry/scripts'; then
    HOMEBREW_NO_AUTO_UPDATE=1 brew untap anzihenry/scripts >/dev/null 2>&1 || true
  fi
  rm -rf "$TMPDIR_ROOT"
}
trap cleanup EXIT

mkdir -p "$TMPDIR_ROOT/work"
rsync -a --exclude '.git' --exclude '.DS_Store' "$WORKSPACE/" "$TMPDIR_ROOT/work/"
cd "$TMPDIR_ROOT/work"

git init -b main >/dev/null
git config user.name 'Test Runner'
git config user.email 'test@example.com'
git add . >/dev/null
git commit -m 'test snapshot' >/dev/null
git clone --bare "$TMPDIR_ROOT/work" "$TMPDIR_ROOT/repo.git" >/dev/null

cd "$WORKSPACE"

echo '=== stable install test ==='
HOMEBREW_NO_AUTO_UPDATE=1 brew tap --custom-remote anzihenry/scripts "file://$TMPDIR_ROOT/repo.git"
HOMEBREW_NO_AUTO_UPDATE=1 brew install anzihenry/scripts/macos-scripts
./bin/macos-scripts --version

HOMEBREW_NO_AUTO_UPDATE=1 brew uninstall --formula macos-scripts
HOMEBREW_NO_AUTO_UPDATE=1 brew untap anzihenry/scripts

echo '=== bootstrap test ==='
HOMEBREW_NO_AUTO_UPDATE=1 TAP_REMOTE_URL="file://$TMPDIR_ROOT/repo.git" zsh bootstrap/install.sh --yes --skip-configure
macos-scripts --version
EOF

chmod +x /tmp/macos-scripts-install-test.sh
zsh /tmp/macos-scripts-install-test.sh
```

### Create and push tag

```bash
git checkout main
git pull --ff-only origin main
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```

### Verify remote tag and bootstrap URL

```bash
git ls-remote --tags origin | grep "refs/tags/v0.1.0$"
curl -I https://raw.githubusercontent.com/anzihenry/scripts/v0.1.0/bootstrap/install.sh
```

### Publish through CLI

```bash
./bin/macos-scripts release publish v0.1.0 \
  --yes
```

### Equivalent underlying command

```bash
bash maintain/github_release_publish.sh \
  --tag v0.1.0 \
  --notes-file docs/releases/0.1.0/README.md \
  --update-existing \
  --yes
```

### Verify-only

```bash
./bin/macos-scripts release verify v0.1.0
```

### Historical bootstrap snippet in the release-note draft

```bash
BOOTSTRAP_TAG="v0.1.0"
curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh
```

### Bootstrap wording inspection

```bash
zsh bootstrap/install.sh --help | grep 'v0.1.0'
rg 'raw.githubusercontent.com/anzihenry/scripts/main/bootstrap/install.sh|--HEAD|head-only|BOOTSTRAP_TAG' README.md bootstrap/install.sh Formula/macos-scripts.rb
```

## Acceptance expectations

The version output must be macos-scripts v0.1.0; bootstrap URL/tag/flow and public wording must match. Required syntax, lint, smoke, and applicable guards must pass.

The historical local-install rehearsal uses a temporary Git snapshot/bare repository and TAP_REMOTE_URL=file://... to exercise stable tap installation and bootstrap before remote tap changes. Both installations must print v0.1.0. Remove the test Formula/tap afterward and confirm no test state remains. Installation behavior and documented steps must agree.

## Tag and publication

Create/push the annotated tag only when main contains the intended release commit. The remote must contain refs/tags/v0.1.0, and the raw bootstrap URL must return 200 OK. Publish a normal Release targeting main, titled v0.1.0; use the CLI when UI tools are unreliable. Verify-only checks state without publishing.



## After release

Check piped bootstrap dry-run, real tap installation, and release body agreement with [notes](README.en.md). Also test on a macOS machine without macos-scripts; test HEAD separately if needed.



## Bootstrap copy and known limits

Check tagged URLs rather than main, bootstrap --help, and Formula caveats. Clearly distinguish bootstrap (first Homebrew installation plus CLI) from setup brew configure (existing Homebrew configuration/repair), stable from HEAD, and remote-tag prerequisites. The local rehearsal covers a machine already equipped with Homebrew/Xcode CLI. The actual no-Homebrew branch still requires clean macOS or a VM.

The embedded historical release-note draft describes the unified setup/maintain/job/lint entry, standalone bootstrap, tap Formula, installed log/configuration directories, command help and validation, and stable/HEAD installation. The [English notes](README.en.md) provide the translated release description.
