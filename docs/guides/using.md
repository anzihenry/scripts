---
title: 使用与维护
status: current
owner: project-maintainers
updated: 2026-10-22
---

# 使用与维护

[English](using.en.md)

> 本指南中新增的日志、预检和无副作用查询规则面向当前未发布源码。固定 `v0.5.0` 的 stable 安装不会自动获得本轮行为；版本范围与本地验证方式见[安装指南](installation.md)。

## 🧭 统一 CLI

```bash
./bin/macos-scripts setup shell
./bin/macos-scripts setup brew configure
./bin/macos-scripts setup packages
./bin/macos-scripts setup git --domain gitlab.company.com --type work
./bin/macos-scripts setup github

./bin/macos-scripts maintain brew --dry-run
./bin/macos-scripts maintain installer list

./bin/macos-scripts lint check
```

> 当前 `bin/macos-scripts` 是统一入口，现有 `setup/`、`maintain/`、`lint/` 脚本继续作为内部执行器保留。
> 入口本身已拆分为 `bin/macos-scripts` + `bin/lib/*.sh`，帮助文案与参数校验逻辑不再和分发逻辑混在同一个文件里。

帮助和版本查询是纯查询：`macos-scripts --help`、`macos-scripts help <主题>`、子命令 `--help`，以及 `macos-scripts version` / `--version` / `-v` 均直接输出结果，不创建配置或日志目录、不写入或轮转日志、不获取锁，也不检查系统版本、架构或网络。独立脚本的帮助入口遵循相同规则。日志路径不可写或日志轮转参数无效时，仍可查看帮助和版本；实际执行才初始化运行环境；`setup packages` 和 `setup shell` 的 dry-run 同样保持无写入。未知命令、无效参数及版本查询的多余参数返回非零并给出提示。

GitHub 配置默认不带 `--force`；仅在明确需要重建已有 SSH 密钥时显式添加该选项。

## 重复执行约定

初始化脚本按“相同参数收敛到同一目标状态”执行：资源健康且配置一致时跳过安装或写入；日志、耗时与在线状态检查可以变化。维护命令仍可获取新版本，`--force` 仍表示显式重建。

| 功能 | 重复执行行为 |
|---|---|
| 公共配置 | 配置块保留原位置；内容相同不替换文件；不完整、重复或交错的标记拒绝写入；保留有效符号链接和既有权限 |
| `setup shell` | 不覆盖 `.zshrc`，保留用户主题和插件；健康仓库及本地修改不删除；克隆、字体下载校验后才放入目标位置；配置锁阻止并发初始化 |
| `setup brew configure` | 配置块和 Git remote 均一致时跳过备份与写入；需要变更时继续使用事务备份和回滚 |
| `setup git` / `github` | 匹配公私钥直接复用；未加密私钥可补回缺失公钥；不同域名隔离，已有明确归属的旧别名兼容；相同 SSH 配置不重写 |
| GitHub 公钥 | 使用 `GH_TOKEN`、`GITHUB_TOKEN` 或已有 `gh` 登录令牌，缺少凭据才读取输入；分页查询已有公钥后再决定上传；查询/上传失败返回非零，已有本地身份保留 |
| `setup packages` | Homebrew 已有包跳过；批量部分失败后复查已安装项；已有本地 LTS 用 `nvm use --lts` 激活，不隐式升级 Node/npm；pip 按键合并，镜像一致不重写；PATH 去重 |
| 安装器下载 | 检查 `createinstallmedia`、载荷镜像完整性及载荷元数据中的 macOS 版本；版本按组件边界匹配；无版本指定时按修改时间选择完整安装器 |
| USB 制作 | 设备锁内复查；同时匹配卷 UUID、安装载荷/Info 摘要、完成记录、应用版本与引导标记才跳过；`--force` 可重做；没有可信完成记录的已有安装器须显式确认覆盖 |
| Homebrew 维护 | 仍更新软件和元数据；Cask 检测失败不再报告整体成功，可重新执行 |

SSH `--force` 会把旧密钥保留在配置目录的 `backups/ssh-key.<随机标识>/`，不会自动删除，以便恢复。加密私钥缺失公钥时，自动恢复会停止并保留原文件，需要先解锁再手动导出。无法验证的已有仓库也会保留并提示检查，不自动删除。

安装器校验会读取完整镜像；读取现代安装载荷元数据时会临时只读挂载并在退出时卸载。USB 完成记录位于配置目录的 `installer-state/<卷 UUID>`；手动制作或旧版本制作的 U 盘没有该记录时，脚本保守地要求 `--force`，不会仅凭同名 `.app` 判定完成。真实安装和抹盘仍需在目标机器上验证。

Node 的显式升级可使用上游 nvm 命令；初始化复用已安装的 LTS。[nvm 用法](https://github.com/nvm-sh/nvm#long-term-support)、[GitHub CLI 查询接口](https://cli.github.com/manual/gh_api)。

## 模块选择、预览与恢复

```zsh
macos-scripts setup packages --dry-run --modules node,python
macos-scripts setup packages --modules node,python
macos-scripts setup shell --dry-run
```

`--modules` 可选 `node,python,ruby,go,android,packages`，默认全部；重复项去重，未知项在执行前拒绝。`packages` 表示 `brew.conf.sh` 中的 Formulae/Cask 列表，`android` 仅生成 Android/Java 环境配置。选择任意模块仍会校准 Homebrew 并检查 Command Line Tools；安装后只验证选择的语言模块。实际执行按阶段报告耗时，失败显示已完成、失败、未执行阶段和恢复建议。

上述两个初始化入口的 `--dry-run` 只打印计划，不联网、不创建配置/日志/锁、不执行用户的 `brew.conf.sh`。CLI 和独立脚本共享参数解析。其他命令的 dry-run 仍可能查询系统或远端并记录日志，以各命令帮助为准。

默认配置集中在 `setup/lib/setup_defaults.sh`。可用同名环境变量覆盖：`SETUP_NPM_REGISTRY`、`SETUP_PIP_INDEX`、`SETUP_PIP_HOST`、`SETUP_GEM_SOURCE`、`SETUP_GOPROXY`、`SETUP_GOPATH`、`SETUP_JAVA_HOME`、`SETUP_ANDROID_HOME`。Homebrew 仍默认 USTC。pip 的多个键先在候选文件上更新，全部成功才一次提交；失败保留原文件。

所有公共配置写入按实际路径加锁，符号链接与目标共用锁；Homebrew 事务持锁覆盖备份、写入及回滚，防止回滚覆盖其他入口的更新。Homebrew 安装、初始化和维护按 prefix 协调；Bootstrap 调用独立配置 CLI 前释放并由子进程重新获取锁。终端和 SSH 也有业务锁。锁采用系统 Zsh 的 `zsystem flock`，等待默认 10 秒，可用 `MACOS_SCRIPTS_LOCK_TIMEOUT` 设置 0–9999 秒。锁文件保留于 `/tmp/macos-scripts-locks-<UID>/`，进程退出后内核释放锁，**不要删除锁文件**。旧版本残留的目录锁若无法确认安全仍会提示人工检查。

锁仅协调本项目的合作进程，不阻止编辑器或手动命令修改资源。同步嵌套函数可复用父事务锁，禁止在持锁事务中并行派生共享写入。SIGKILL/断电会释放内核锁，但无法执行回滚；已完成安装保留，重新运行会检查当前状态，未完成回滚时保留的备份可用于手动恢复。信号退出码为 INT=130、TERM=143、HUP=129。日志记录器失败会提示日志不完整，保留业务退出码。

公共实现位于 `lib/config_writer.sh`、`lib/command_runtime.sh`、`lib/resource_lock.sh`、`lib/workflow.sh`；旧配置写入器/命令执行器导入路径仍兼容。SSH 入口将身份、配置、GitHub API、连接提示分别放在 `setup/lib/ssh_*.sh` 和 `github_keys.sh`。

## 🧰 常用工具脚本

### Shell 脚本 Lint & 格式化

```bash
./lint/lint_shell.sh           # 检查 Zsh shebang 与语法
./lint/lint_shell.sh --fix     # 兼容入口，仅检查并提示不自动格式化
```
> 无需额外依赖。仓库统一使用 Zsh，执行 shebang 校验与 `zsh -n`。ShellCheck/shfmt 不支持 Zsh，运行时验证见[开发指南](development.md)。

### Homebrew 日常维护

```bash
cd maintain
./formulaes_casks_updater.sh --dry-run  # 预览更新命令
./formulaes_casks_updater.sh            # 更新所有 Formulae/Cask，安装态下失败项写入 ~/Library/Logs/macos-scripts/brew_update_errors.log
```

### macOS 安装器下载 & USB 启动盘制作

```bash
cd maintain
# 列出可用完整安装器
./macos_sys_usb_maker.sh list

# 下载指定版本安装器（幂等、可加 --force）
./macos_sys_usb_maker.sh download --version 14.6.1

# 制作 USB 启动盘（需要 sudo，支持 --force 覆盖、--yes 跳过交互）
./macos_sys_usb_maker.sh create --volume /Volumes/MyUSB --version 14.6 -y
```
> 脚本为关键命令记录耗时，并使用锁避免并发冲突；通过 `macos-scripts` 安装态运行时，日志默认写入 `~/Library/Logs/macos-scripts/macos-installer.log`。

更多见[安装与配置](installation.md)、[发布指南](releasing.md)。

Homebrew 配置的未完成事务在下次运行时检查：内容匹配检查点则自动恢复；后续编辑、备份损坏或未记录写入会停止，保留备份并提示人工处理。恢复成功保留旧备份，新事务成功删除本次备份。
