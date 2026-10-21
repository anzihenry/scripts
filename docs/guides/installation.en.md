---
title: Installation and setup
status: current
owner: project-maintainers
updated: 2026-10-21
---

# Installation and setup

[中文](installation.md)

Translation of the Chinese primary version. Commands and historical log excerpts retain their original language where applicable.

Run commands from the repository root; after installation, use `macos-scripts` instead of `./bin/macos-scripts`.

All execution entry points require **macOS 14+**, including direct scripts and `curl … | zsh`. Unsupported or unreadable versions stop before installation, downloads, or configuration changes with corrective guidance. Help and CLI `version` / `--version` remain available; `--dry-run` also checks the minimum version.

> **Version scope:** The rollback, bounded logging, precheck, and read-only query behavior below describes current unreleased source. Commands pinned to `BOOTSTRAP_TAG="v0.5.0"` download that older release and do not include this work. Even a local updated bootstrap installs the stable CLI selected by the tap Formula, so it does not guarantee unreleased child-CLI behavior. Inspect local source with `zsh bootstrap/install.sh --help` and `./bin/macos-scripts --help`. These changes still need a commit, a new release tag, and an updated Formula before stable installation can provide them.

## First bootstrap

On a fresh macOS machine without Homebrew, use the standalone bootstrap:

```bash
BOOTSTRAP_TAG="v0.5.0"
curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh -s -- --yes
```

It checks/installs Xcode CLI tools, installs Homebrew, installs `macos-scripts` through the tap, and runs `macos-scripts setup brew configure`.

Run bootstrap as a regular user, without `sudo zsh bootstrap/install.sh` or `curl … | sudo zsh`. The entry point checks the effective user ID and rejects root before creating logs, configuration directories, locks, or starting installation, with guidance to remove sudo or leave the root session and retry. Dry-run follows the same rule. Root may still use `--help`, `-h`, or `help` without creating or modifying logs, directories, or locks. During a regular-user run, the relevant installer handles any required administrator privileges; bootstrap does not switch users automatically.

Bootstrap accepts only `arm64` or `x86_64` from `uname -m`; unsupported, empty, or unreadable results stop before acquiring a run lock, installing, or downloading. Logs show the execution architecture, which may be `x86_64` under Rosetta. Following [Apple’s Rosetta detection guidance](https://developer.apple.com/documentation/apple-silicon/about-the-rosetta-translation-environment), x86_64 runs query `sysctl.proc_translated`; a confirmed value of `1` prompts users to switch to a native terminal by disabling “Open using Rosetta” for their terminal app and restarting it. This advisory allows execution to continue and preserves existing Homebrew discovery without automatic migration or reinstallation. A missing key on Intel does not trigger a Rosetta warning. Help skips this check; dry-run performs it.

On repeated runs, an installed `macos-scripts` skips installation and upgrades, then continues configuration unless `--skip-configure` is set. Dry-run follows the same rule. Run `macos-scripts maintain brew` separately to update.

After installation or skipping an existing installation, bootstrap checks that the command exists and runs `macos-scripts --version`. Success displays the actual version and continues without requiring it to match bootstrap's built-in version. This check also runs with `--skip-configure`. Failure stops bootstrap with the log location and the manual repair command `brew reinstall anzihenry/scripts/macos-scripts`. Dry-run only previews the check.

Local and piped execution read confirmation from `/dev/tty`, leaving script input untouched. Only `y` or `Y` continues; Enter, other input, or EOF cancels with a successful exit. Without an interactive terminal, bootstrap exits nonzero and asks you to add `--yes`. Neither `--yes` nor `--dry-run` reads confirmation.

Actual bootstrap acquires a run lock after prechecks and before confirmation, protecting confirmation, CLT, Homebrew, tap, CLI installation, and subsequent configuration. With the default configuration directory, only one bootstrap per user may run; a second process immediately exits nonzero without queuing. The mode-700 directory `~/.config/macos-scripts/.bootstrap.lock` (overridable with `MACOS_SCRIPTS_CONFIG_DIR`) contains a `pid` file identifying the owner. Completion, cancellation, failure, and catchable INT/TERM/HUP signals release the lock. Help and dry-run neither create nor acquire the lock and remain usable while another process holds it. A force-killed process may leave a lock, which is never automatically reclaimed: inspect the PID, verify the original process has ended, then delete `pid` and remove the lock directory before retrying.

Failures retain the original command errors and end with a single summary identifying the failed stage, exit code, log path, and recovery guidance. Stages distinguish installer download/execution, tap creation, CLI installation/validation, and configuration. Catchable INT/TERM/HUP signals report an interruption and current stage, with logs and recovery guidance. User cancellation exits successfully without a failure summary, and recovered errors such as an official failure followed by USTC success do not produce a final failure summary. After fixing the specific problem, rerun the original bootstrap command; completed, usable installations are skipped.

Local execution (`zsh bootstrap/install.sh`) and piped execution (`curl … | zsh`) use the same Command Line Tools (CLT) rules. An existing developer path must also pass `xcrun --find clang`; a path with an unlocatable compiler stops immediately with repair guidance rather than restarting installation. A missing path opens the system installer, then checks both the path and compiler lookup every five seconds for up to ten minutes. Both must be ready before continuing. An installation launch failure or timeout stops bootstrap; complete or repair installation before rerunning. Dry-run checks an existing toolchain but only previews missing-tool installation without opening a dialog, waiting, or attempting compiler lookup before a developer path exists.

`--yes` skips the script confirmation and sets `NONINTERACTIVE=1` for official and USTC Homebrew installer subprocesses, removing a conflicting `INTERACTIVE` without changing the parent environment. The CLT system dialog still requires manual interaction. Official Homebrew non-interactive mode also does not prompt for an administrator password; if privileges are insufficient, rerun without `--yes` in a terminal. `--dry-run` needs no confirmation, does not launch or wait for CLT installation, and does not install Homebrew or the tap package. Prechecks and bootstrap logging still run.

Homebrew installation tries the official source first, then checks `brew --version`. If brew is usable, bootstrap continues even when the installer returned nonzero; otherwise it automatically tries USTC. It stops if installation fails at both sources or brew remains unusable, preserving installer output and the log path. Failed, empty, or partially downloaded responses are never executed by Bash.

Existing Homebrew detection checks the first `brew` found in PATH, `/opt/homebrew/bin/brew`, and `/usr/local/bin/brew` in that order, selecting the first entry whose `--version` succeeds. Candidates pointing to the same physical file are checked only once. If an earlier entry fails and a later one works, bootstrap reports the selected path and uses it for tap, list, and install commands. Installation starts only when no candidate is usable. Local and piped execution follow the same rules.

Both installer script downloads allow up to 10 seconds to connect and 120 seconds total per download. An official download timeout follows the same brew recheck and automatic fallback flow; if the USTC download also fails, bootstrap stops with network troubleshooting and retry guidance. These limits apply only to script downloads, not the subsequent Homebrew installation. Dry-run displays the timeout arguments.

Common options:

```bash
BOOTSTRAP_TAG="v0.5.0"
curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh -s -- --dry-run --yes
curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh -s -- --yes
curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh -s -- --skip-configure
```

Bootstrap logs default to `~/Library/Logs/macos-scripts/bootstrap.log`. These published examples pin a tag. If that tag is not yet on the remote, run `zsh bootstrap/install.sh` locally or complete the release first.

### Recovering from Homebrew configuration failure

Repeated configuration first compares managed blocks and remotes; matching target state skips backups and writes. See [repeated execution](using.en.md#repeated-execution) for the other scripts.

Bootstrap still configures USTC by default; `--skip-configure` skips configuration. Before changes, it backs up `.zshrc` and existing brew/core Git configuration files in `~/.config/macos-scripts/backups/homebrew-config.<random>/` (overridable with `MACOS_SCRIPTS_CONFIG_DIR`). Backup directories are accessible only to the current user.

Write or mirror verification failures and catchable interruption signals restore these files and return nonzero. An originally absent `.zshrc` is removed on rollback; existing symlinks and target permissions are preserved. Installed Homebrew and the CLI remain installed. Success removes only the current run's backup; failures retain backups and print their paths. Later successful runs preserve backups from earlier failures. Cleanup failures prompt manual deletion without failing an otherwise successful configuration. If restoration itself fails, use `manifest.tsv` to map numbered backups to their original paths for manual recovery; the command does not claim complete restoration.

Configuration validates mirror connectivity without `brew update-reset` or worktree changes. An absent core tap is not cloned; API mirror configuration is retained. Run `macos-scripts maintain brew` for actual updates. Dry-run creates no configuration backup or lock. If a force-killed process leaves a lock, verify no other configuration process is running before removing the lock directory shown in the error.

## Homebrew installation

Install through the repository's Formula and tap. If Homebrew is absent, bootstrap first; the Formula does not install Homebrew itself.

```bash
# 添加 tap（仓库中包含 Formula/macos-scripts.rb）
brew tap anzihenry/scripts https://github.com/anzihenry/scripts

# 安装稳定版
brew install anzihenry/scripts/macos-scripts

# 验证
macos-scripts --help
```

To install the latest development code:

```bash
brew install --HEAD anzihenry/scripts/macos-scripts
```

The stable Formula targets the `v0.5.0` source archive; bootstrap also installs stable by default. Homebrew links the CLI into `bin/` and installs scripts into `libexec/`, preserving relative paths.

Bootstrap, the CLI, and directly executed scripts share the default log directory. The installed CLI uses the following configuration directory:

```bash
MACOS_SCRIPTS_LOG_DIR="$HOME/Library/Logs/macos-scripts"
MACOS_SCRIPTS_CONFIG_DIR="$HOME/.config/macos-scripts"
```

Homebrew maintenance errors go to `~/Library/Logs/macos-scripts/brew_update_errors.log`.

### Log locations

- Every entry point defaults to `~/Library/Logs/macos-scripts/`, with no fallback to repository or script directories.
- Export `MACOS_SCRIPTS_LOG_DIR` to override the location. Bootstrap passes its actual directory to the CLI. An unavailable directory or unwritable log file produces an error and stops execution rather than silently selecting another location.
- Confirmed legacy run logs in the repository root, `setup/`, and `maintain/` have been removed. Subsequent runs use the shared directory without scanning or deleting unrelated files. Use the log directory and file path printed by the current run.

| Feature | Log file within the shared directory |
| --- | --- |
| Bootstrap | `bootstrap.log` |
| Homebrew configuration | `homebrew-setup.log` |
| Shell setup | `setup-shell.log` |
| Development environment and packages | `macos-setup.log` |
| Git / SSH configuration | `setup-git.log` |
| macOS installer | `macos-installer.log` |
| Release publishing | `github-release-publish.log` |
| Homebrew maintenance failures | `brew_update_errors.log` (written when failures occur) |

Successful bootstrap summarizes the actual Homebrew and CLI paths, CLI version, completed or skipped USTC configuration, and log directory/file location. Dry-run reports a completed preview without claiming installation, CLI validation, or configuration occurred.

Help and CLI version queries do not initialize logs or directories, rotate or prune logs, acquire locks, or run environment checks. This also applies to bootstrap help for both root and regular users. Queries work even when the configured log path is unusable. Invalid arguments fail before executor log initialization without reporting a nonexistent log path.

Each feature execution (including dry-run) appends a `===== 运行开始 =====` separator with its start time and UTC offset, script name, actual-execution or dry-run mode, and PID, preserving existing content. This metadata does not record complete arguments or their values. Local and piped bootstrap both identify as `install.sh`; CLI operations identify their underlying script. `brew_update_errors.log` is still created only on failure: the first failure adds the run's start metadata, and later failures in that run reuse the same header.

The logger runs as a waitable child through a private FIFO whose temporary path is removed after opening. Normal exits, explicit failures, and catchable interruptions drain it while preserving the business exit code. Runtime log failures warn once and retain terminal output. Log symlinks are rejected before opening, so dangling links cannot create target files.

### Log size and retention

Logs rotate by byte size during writing, rather than only at startup. Defaults are **5 MiB** per active file and at most **5 archives**, numbered `.1` (newest) through `.5` (oldest). Archives obey the same size limit; the oldest excess content is removed while console output remains complete. When taking over an oversized existing log, only its last size-budget bytes are retained as an archive.

Starting capture or appending maintenance errors removes that feature's archives older than **30 days**. Active logs are not deleted based on age. Cleanup runs on use, without scheduled jobs, and only manages numeric archives for the corresponding log. Kernel file locks serialize concurrent writes; `.log.lock` files remain as lock handles, with locks released automatically when their processes exit. Symlink log paths are rejected.

All entry points, including standalone bootstrap, accept these environment settings:

```zsh
export MACOS_SCRIPTS_LOG_MAX_BYTES=5242880
export MACOS_SCRIPTS_LOG_BACKUPS=5
export MACOS_SCRIPTS_LOG_RETENTION_DAYS=30
```

Values must be positive integers, capped at 1 GiB, 100 archives, and 3650 days respectively. Startup write failures stop execution. Runtime write/rotation failures produce an explicit warning while console output continues.

## Four steps to set up a developer environment

### 1. Terminal setup

Install Oh My Zsh, Powerlevel10k, and fonts:

```bash
cd setup
./ohmyzsh-setup.sh
```

Follow the font instructions and restart the terminal.

### 2. Homebrew configuration

Configure or repair existing Homebrew mirrors and shellenv:

```bash
./homebrew-setup.sh
```

For a fresh machine, bootstrap first. To preview from the repository root, run `./bin/macos-scripts setup brew configure --dry-run`.

### 3. Packages

Install development tools and GUI applications:

```bash
# 如需自定义安装清单，先编辑 setup/brew.conf.sh
./macos-setup.sh
```

Edit `setup/brew.conf.sh` first if needed. The script uses `setup/lib/brew_helpers.sh` for batch/per-item installation and reports success, skipped items, failures, and timing.

### 4. Git hosting SSH keys

Optionally configure SSH keys for Git hosting platforms:

```bash
./git_forge_ssh_setup.sh -d github.com -t personal
./git_forge_ssh_setup.sh -d gitlab.company.com -t work
```

## Customize package lists

- In the repository, edit the `FORMULAE_*` and `CASKS_*` arrays in `setup/brew.conf.sh`.
- In installed mode, the first `macos-scripts setup packages` copies defaults to `~/.config/macos-scripts/brew.conf.sh`; edit that copy afterward.
- Installed `setup shell` and `setup git` place backups in `~/.config/macos-scripts/backups/`.
- `macos-setup.sh` loads these arrays and installs through shared helpers.
- Set `BH_DRY_RUN=true` to print planned installation items without installing them.
