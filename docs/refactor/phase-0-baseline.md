# Phase 0 Baseline

## 目标

在进入渐进式重构前，先冻结当前仓库的关键入口、验证命令、环境约束与已知差异，作为后续每一阶段的回归参照。

## 基线范围

- CLI 入口：`bin/macos-scripts`
- setup 流程：`setup/homebrew-setup.sh`、`setup/macos-setup.sh`
- maintain 流程：`maintain/formulaes_casks_updater.sh`、`maintain/macos_sys_usb_maker.sh`
- lint 入口：`lint/lint_shell.sh`

## 基线命令

以下命令作为阶段性回归的最小检查集：

```bash
./lint/lint_shell.sh
zsh bin/macos-scripts --help
zsh bin/macos-scripts setup brew configure --dry-run
zsh bin/macos-scripts maintain brew --dry-run
zsh bin/macos-scripts maintain installer list
```

## 本次记录结果

记录日期：2026-04-25

### 1. CLI help

命令：

```bash
zsh bin/macos-scripts --help
```

结果：

- 成功输出一级命令帮助
- 当前版本为 `v0.2.0`

### 2. setup brew configure dry-run

命令：

```bash
zsh bin/macos-scripts setup brew configure --dry-run
```

结果：

- 在当前 Codex 沙箱环境中失败
- 失败原因为前置网络检查未通过：`中科大源异常，网络连接失败，请检查网络设置`
- 同时脚本尝试写入 `~/Library/Logs/macos-scripts/homebrew-setup.log` 时触发权限限制

结论：

- 当前失败不能直接判定为脚本功能回归
- 后续重构验证时，需要区分“仓库逻辑变化”和“沙箱/网络限制”

### 3. maintain brew dry-run

命令：

```bash
zsh bin/macos-scripts maintain brew --dry-run
```

结果：

- 成功完成 dry-run 路径
- `brew update`、`brew upgrade`、`brew cleanup` 均进入预览分支
- 检测到 7 个可更新 Cask，全部命中默认排除列表

### 4. maintain installer list

命令：

```bash
zsh bin/macos-scripts maintain installer list
```

结果：

- 在当前 Codex 沙箱环境中未稳定返回
- 调用链已进入 `softwareupdate --list-full-installers`
- 同时脚本尝试写入 `~/Library/Logs/macos-scripts/macos-installer.log` 时触发权限限制

结论：

- 该命令后续应优先在本机真实终端环境复核
- 阶段 0 先把它作为“受环境影响的基线项”记录，而不是功能通过项

### 5. lint

命令：

```bash
zsh lint/lint_shell.sh
```

结果：

- 成功
- 共检测到 17 个 Shell 文件
- 当前策略为：
  - zsh：语法检查
  - bash/sh：语法检查 + shellcheck + shfmt

附加发现：

- `lint/lint_shell.sh` 原本缺少可执行权限，导致 `./lint/lint_shell.sh` 无法直接运行

## 当前约束与已知差异

### 1. `maintain/` 规范与实现存在漂移

- 目录说明期望 `maintain/` 兼容 `bash 3.x`
- 当前核心脚本 `maintain/formulaes_casks_updater.sh`、`maintain/macos_sys_usb_maker.sh` 使用的是 `zsh`

建议：

- 在后续重构前先明确目标：统一到 `zsh`，或逐步回收至 `bash 3.x`

### 2. 日志路径依赖用户目录写权限

- 多个脚本默认写入 `~/Library/Logs/macos-scripts/`
- 在沙箱环境中，这一行为可能被拒绝

建议：

- 后续阶段保留默认路径不变
- 但验证时允许通过环境变量覆盖日志目录，避免把环境权限问题误判为功能问题

### 3. zsh 文件的静态检查覆盖仍偏弱

- 当前 lint 对 zsh 文件仅做语法检查，不做 shellcheck/shfmt

建议：

- 作为后续阶段的增强项，不在阶段 0 直接扩展规则，避免一次性引入大量格式噪音

## 阶段 0 交付物

- 基线文档：本文件
- 基线命令集：见上文
- lint 入口可执行性修复：允许直接运行 `./lint/lint_shell.sh`

## 阶段 0 完成标准

- 有可复用的最小回归命令集
- 有受环境影响项的显式记录
- 有规范/实现漂移项的显式记录
- 不修改现有业务流程与 CLI 语义
