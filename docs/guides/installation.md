---
title: 安装与初始化
status: current
owner: project-maintainers
updated: 2026-10-21
---

# 安装与初始化

[English](installation.en.md)

命令在仓库根目录执行；安装态使用 `macos-scripts` 替代 `./bin/macos-scripts`。

所有执行入口统一要求 **macOS 14+**，包括直接运行脚本和 `curl … | zsh`。低版本或无法读取系统版本时，在安装、下载及配置修改前中止并提示修复；`--help` 和 CLI `version` / `--version` 仍可使用。`--dry-run` 同样检查最低版本。

> **版本范围：** 下文的回滚、有界日志、预检和纯查询行为描述当前未发布源码。固定 `BOOTSTRAP_TAG="v0.5.0"` 的命令会下载该旧版本，不包含本轮改动；即使运行本地新版 bootstrap，默认安装的 stable CLI 也由 tap 中的 Formula 决定，不能据此假定子 CLI 已具备未发布行为。本地审阅可使用 `zsh bootstrap/install.sh --help` 和 `./bin/macos-scripts --help`；这些改动仍需提交、发布新 tag 并更新 Formula 后，才能通过 stable 安装获得。

## ⚡ 首次 Bootstrap

如果这是台全新的 macOS，且系统里还没有 Homebrew，优先使用独立 bootstrap 入口：

```bash
BOOTSTRAP_TAG="v0.5.0"
curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh -s -- --yes
```

这个入口会依次完成：

1. 检查并安装 Xcode CLI
2. 安装 Homebrew
3. 通过 tap 安装 `macos-scripts`
4. 自动执行 `macos-scripts setup brew configure`

请以普通用户执行 bootstrap，不要使用 `sudo zsh bootstrap/install.sh` 或 `curl … | sudo zsh`。入口使用有效用户 ID 检查 root，在创建日志、配置目录、运行锁及任何安装前返回非零，提示去掉 `sudo` 或退出 root 会话后重试；`--dry-run` 也遵循此规则。root 下的 `--help`、`-h`、`help` 仍可显示帮助，且不创建或修改日志、目录和锁。普通用户执行时，后续安装步骤所需的管理员权限由对应安装器处理；脚本不会自动切换用户。

bootstrap 预检只接受 `uname -m` 返回的 `arm64` 或 `x86_64`；其他架构、空结果或读取失败会在获取运行锁、安装和下载前中止。日志显示的是运行架构，Rosetta 下可能为 `x86_64`。根据 [Apple 的 Rosetta 检测说明](https://developer.apple.com/documentation/apple-silicon/about-the-rosetta-translation-environment)，在 x86_64 环境查询 `sysctl.proc_translated`，明确为 `1` 时提示切换原生终端（关闭终端应用的“使用 Rosetta 打开”后重启）。提示不阻断执行，也不自动迁移、重装或改变现有 Homebrew 的探测顺序。Intel 上查询键不存在时正常继续，不误报 Rosetta。`--help` 跳过架构检查；`--dry-run` 同样校验并显示提示。

重复运行时，已安装的 `macos-scripts` 会跳过安装和升级，继续执行配置（`--skip-configure` 除外）；`--dry-run` 也遵循该规则。如需更新，请单独执行 `macos-scripts maintain brew`。

安装或跳过安装后，先检查命令是否存在，再执行 `macos-scripts --version`；成功时显示实际版本并继续，不要求与 bootstrap 内置版本一致。即使使用 `--skip-configure` 也会验证 CLI。执行失败时中止并提示日志位置及手动修复命令 `brew reinstall anzihenry/scripts/macos-scripts`。`--dry-run` 仅展示检查计划。

本地与管道入口均从 `/dev/tty` 读取安装确认，不消耗脚本的标准输入。仅输入 `y` 或 `Y` 才继续；回车、其他输入或 EOF 均取消并正常退出。没有可交互终端时返回非零，提示添加 `--yes`；`--yes` 和 `--dry-run` 均不读取确认。

实际 bootstrap 在预检后、确认前获取运行锁，保护确认、CLT、Homebrew、tap、CLI 安装及后续配置。同一用户使用默认配置目录时只允许一个流程运行，第二个进程立即返回非零，不排队等待。锁目录为 `~/.config/macos-scripts/.bootstrap.lock`（可由 `MACOS_SCRIPTS_CONFIG_DIR` 覆盖），权限为 700，`pid` 文件记录持锁进程。正常完成、取消、失败或收到可捕获的 INT/TERM/HUP 信号时自动释放锁；`--help` 和 `--dry-run` 不创建或占用锁，已有锁时也可使用。强制终止可能留下锁，脚本不会自动抢占：先查看提示中的 PID、确认原进程已结束，再删除 `pid` 文件并移除锁目录后重试。

失败时保留命令的原始错误，并在结束时统一输出一次失败阶段、退出码、日志路径和恢复建议；阶段会区分下载/执行 Homebrew 安装脚本、添加 tap、安装 CLI、验证 CLI 和配置等步骤。收到可捕获的 INT/TERM/HUP 时改为提示“已中断”及当前阶段，仍提供日志和恢复建议。主动取消正常退出，不报失败；官方失败后 USTC 成功等已恢复的情况也不报最终失败。修复具体问题后可重新运行原 bootstrap 命令，已完成且可用的安装会自动跳过。

本地运行 `zsh bootstrap/install.sh` 与 `curl … | zsh` 对 Xcode Command Line Tools（CLT）使用相同规则：已有开发工具路径时，还须通过 `xcrun --find clang` 验证工具定位；路径存在但无法定位 clang 时立即中止并提示检查/修复，不重复启动安装。路径缺失才触发系统安装窗口，每隔 5 秒检查路径与 clang 定位，最多等待 10 分钟；两者均就绪才继续。启动失败或等待超时会中止，完成或修复系统安装后可重新运行脚本。dry-run 会检查已有工具链；缺失时只预览，不触发窗口、不等待，也不调用未就绪工具的定位。

`--yes` 跳过脚本确认，并为官方和 USTC Homebrew 安装器子进程设置 `NONINTERACTIVE=1`（清除冲突的 `INTERACTIVE`，不修改父进程环境）。CLT 系统窗口仍需手动操作。Homebrew 官方非交互模式也不会交互询问管理员密码；权限不足时会失败，请在终端不带 `--yes` 重试。`--dry-run` 无需确认，不触发 CLT 安装、不等待，也不执行 Homebrew/tap 安装；预检和 bootstrap 日志仍会执行。

Homebrew 安装先尝试官方源，随后验证 `brew --version`。即使官方脚本返回非零，只要 brew 已可用就继续；仍不可用才自动尝试 USTC。两个来源均未完成安装或最终 brew 不可用时中止，保留安装器输出和日志路径。下载失败、空响应或部分下载内容不会交给 Bash 执行。

检测现有 Homebrew 时，依次验证 PATH 中找到的 `brew`、`/opt/homebrew/bin/brew`、`/usr/local/bin/brew`，使用首个能正常执行 `--version` 的入口；指向同一实际文件的重复候选只检查一次。前序入口执行失败、后续入口可用时，会提示实际选用路径，后续 tap、查询和安装使用该入口。所有候选均不可用才进入安装流程，本地与管道入口规则一致。

官方与 USTC 安装脚本下载统一限制为连接最多 10 秒、单次下载总计最多 120 秒。官方下载超时同样进入 brew 可用性复查和自动换源流程；USTC 也下载失败时中止并提示检查网络后重试。时限仅作用于安装脚本下载，不限制后续 Homebrew 安装过程；dry-run 会展示这些参数。

常用选项：

```bash
BOOTSTRAP_TAG="v0.5.0"
curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh -s -- --dry-run --yes
curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh -s -- --yes
curl -fsSL "https://raw.githubusercontent.com/anzihenry/scripts/${BOOTSTRAP_TAG}/bootstrap/install.sh" | zsh -s -- --skip-configure
```

> bootstrap 日志默认写入 `~/Library/Logs/macos-scripts/bootstrap.log`。
> 以上命令按正式发布口径固定到 tag。当前仓库尚未创建对应远端 tag 时，请先在本地执行 `zsh bootstrap/install.sh`，或先完成版本发布。

### Homebrew 配置失败恢复

重复执行时先比较受管理配置块与 remote；都已符合目标状态时跳过备份和写入。其他脚本的重复执行约定见[使用指南](using.md#重复执行约定)。

bootstrap 默认继续执行 USTC 配置；`--skip-configure` 可跳过。配置修改前，备份 `.zshrc` 和现有 brew/core 仓库的 Git 配置到 `~/.config/macos-scripts/backups/homebrew-config.<随机标识>/`（可由 `MACOS_SCRIPTS_CONFIG_DIR` 覆盖），备份目录仅当前用户可访问。

写入、镜像验证失败，或收到可捕获的中断信号时，恢复本次修改并返回非零；原来不存在的 `.zshrc` 会恢复为不存在，已有符号链接及目标文件权限保留。已安装的 Homebrew 和 CLI 不卸载。配置成功后自动删除本次备份；失败时保留备份，输出会给出具体路径，此后的成功运行不会删除此前失败的备份。若清理备份失败，会提示手动删除，不影响已成功的配置；若恢复自身失败，按该目录的 `manifest.tsv` 中路径与编号备份文件手动恢复，不会提示“已全部恢复”。

配置阶段只修改镜像设置、验证远端连通性，不再调用 `brew update-reset` 或修改仓库工作区；缺少 core tap 时保留 API 镜像配置，不强制克隆。实际更新请执行 `macos-scripts maintain brew`。`--dry-run` 不创建配置备份或锁。若配置进程被强制终止导致锁残留，确认没有其他配置进程后再清理提示中的锁目录。

## 🍺 Homebrew 安装

仓库已经具备 Homebrew Formula 结构，推荐通过 tap 安装。

如果系统尚未安装 Homebrew，请先使用上面的独立 bootstrap 入口，不要试图靠 formula 自举。

```bash
# 添加 tap（仓库中包含 Formula/macos-scripts.rb）
brew tap anzihenry/scripts https://github.com/anzihenry/scripts

# 安装稳定版
brew install anzihenry/scripts/macos-scripts

# 验证
macos-scripts --help
```

如需安装开发中的最新版本，可选：

```bash
brew install --HEAD anzihenry/scripts/macos-scripts
```

> 当前 stable Formula 将固定到 `v0.5.0` 源码归档；bootstrap 默认也会安装 stable 版本。

安装后 Homebrew 会把 CLI 入口链接到 `bin/`，并把仓库脚本安装到 `libexec/`，从而保留当前相对路径结构。

bootstrap、统一 CLI 和直接运行脚本均默认使用统一日志目录；CLI 安装态的配置目录如下：

```bash
MACOS_SCRIPTS_LOG_DIR="$HOME/Library/Logs/macos-scripts"
MACOS_SCRIPTS_CONFIG_DIR="$HOME/.config/macos-scripts"
```

例如 `macos-scripts maintain brew` 的错误日志默认会写入 `~/Library/Logs/macos-scripts/brew_update_errors.log`。

### 日志位置说明

- 所有入口统一默认写入 `~/Library/Logs/macos-scripts/`，不再回退到仓库或脚本目录。
- 如需自定义，在运行前设置并导出 `MACOS_SCRIPTS_LOG_DIR`；bootstrap 会将实际目录传递给后续 CLI。目录不可创建或文件不可写时明确报错并中止，不静默换位置。
- 仓库根目录、`setup/` 和 `maintain/` 中已确认的旧运行日志已清除；后续只写统一位置，不扫描或删除无关日志。排查本次运行时，以输出的“日志目录”和“日志文件位置”为准。

| 功能 | 日志文件（位于统一目录下） |
| --- | --- |
| 首次安装 | `bootstrap.log` |
| Homebrew 配置 | `homebrew-setup.log` |
| 终端初始化 | `setup-shell.log` |
| 开发环境与软件安装 | `macos-setup.log` |
| Git / SSH 配置 | `setup-git.log` |
| macOS 安装器 | `macos-installer.log` |
| Release 发布 | `github-release-publish.log` |
| Homebrew 维护失败项 | `brew_update_errors.log`（出现失败时写入） |

bootstrap 成功后集中显示实际使用的 Homebrew/CLI 路径、CLI 实际版本、USTC 配置已完成或已跳过，以及日志目录与文件位置。dry-run 仅显示预演完成，不声称安装、版本校验或配置已经执行。

帮助和 CLI 版本查询不启动日志、不创建目录、不触发轮转或清理，也不获取锁或执行环境预检；普通用户和 root 查看 bootstrap 帮助均如此。即使配置的日志路径不可写，查询仍可正常输出。无效参数在进入执行器日志初始化前报错，不会伪报日志路径。

每次执行功能（包括 dry-run）会追加 `===== 运行开始 =====` 分隔标记，记录带时区的开始时间、脚本名称、实际执行或 dry-run 模式及 PID，保留原有日志内容。该标记不记录完整参数或参数值；本地和管道 bootstrap 均标记为 `install.sh`，通过 CLI 执行时记录实际底层脚本名。`brew_update_errors.log` 仍只在发生失败时创建，本次首次失败时补入运行开始信息，同次运行的后续失败不重复写分隔头。

记录器使用私有 FIFO 启动可等待的子进程，通道打开后立即删除临时路径；正常退出、显式失败和可捕获中断会排空记录器，保留业务退出码。运行中日志写入失败只提示一次，终端输出继续保留；日志链接在打开前拒绝，失效链接不会创建目标文件。

### 日志大小与保留策略

日志在写入过程中按字节轮转，而不只在启动时检查。默认当前文件最多 **5 MiB**，保留最多 **5 份归档**，例如 `bootstrap.log.1` 为最新归档、`.5` 为最旧归档；每份归档同样受大小上限约束。超出数量的最旧内容自动删除，终端输出保持完整。接管已有超大日志时，仅保留末尾上限内的内容作为归档。

在启动日志记录或追加维护错误时，清理该功能 **30 天以前的归档**；当前日志不会因年龄被删除。清理随使用触发，不创建定时任务。只处理对应日志的数字归档，不删除其他文件；系统文件锁协调并发写入，锁文件为 `.log.lock`，进程结束后内核自动释放锁。符号链接日志会被拒绝。

可在运行前设置以下环境变量；所有入口（包括独立 bootstrap）遵循相同策略：

```zsh
export MACOS_SCRIPTS_LOG_MAX_BYTES=5242880
export MACOS_SCRIPTS_LOG_BACKUPS=5
export MACOS_SCRIPTS_LOG_RETENTION_DAYS=30
```

三个值均须为正整数，上限分别为 1 GiB、100 份、3650 天。启动时无法写入会中止；运行中发生写入/轮转故障会明确告警，并继续保留终端输出。

## ️💻 四步搭建开发环境

1. **终端美化** – 安装 Oh My Zsh、Powerlevel10k、字体等：
    ```bash
    cd setup
    ./ohmyzsh-setup.sh
    ```
    > 完成后请根据提示设置终端字体，并重启终端。

2. **校准 Homebrew（镜像 + shellenv）**：
    ```bash
    ./homebrew-setup.sh
    ```
    > 该步骤只负责配置/修复已有 Homebrew；如果是全新机器，请先使用上面的 bootstrap 入口完成首次安装。
    > 如需非破坏性预演，可执行 `./bin/macos-scripts setup brew configure --dry-run`。

3. **批量安装开发工具 / GUI 应用**：
    ```bash
    # 如需自定义安装清单，先编辑 setup/brew.conf.sh
    ./macos-setup.sh
    ```
    > 脚本使用 `setup/lib/brew_helpers.sh` 以批量/逐项方式安装，并输出成功/跳过/失败统计与耗时。

4. **（可选）配置多平台 SSH 密钥**：
    ```bash
    ./git_forge_ssh_setup.sh -d github.com -t personal
    ./git_forge_ssh_setup.sh -d gitlab.company.com -t work
    ```

## 🔧 自定义安装清单

- 仓库内运行时，编辑 `setup/brew.conf.sh` 调整 `FORMULAE_*`、`CASKS_*` 数组即可。
- Homebrew 安装态运行时，首次执行 `macos-scripts setup packages` 会自动把默认配置复制到 `~/.config/macos-scripts/brew.conf.sh`，后续编辑该文件即可。
- `macos-scripts setup shell` 与 `macos-scripts setup git` 在安装态下会把备份文件写入 `~/.config/macos-scripts/backups/`，避免把运行产物散落到仓库或安装目录。
- `macos-setup.sh` 会自动加载这些数组并通过新封装的 helper 执行安装。
- 可在运行前通过设置环境变量 `BH_DRY_RUN=true` 做干跑测试（只输出将安装的项目，不实际执行）。
