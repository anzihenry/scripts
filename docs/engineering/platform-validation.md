# 平台验证与安装验收

平台支持目标：macOS 14+，arm64 与 x86_64，系统 `/bin/zsh`。目标与验证结果分开记录。

| 环境 | 沙箱回归 | 真实安装/系统操作 |
| --- | --- | --- |
| 当前本机 macOS 27.0.1 / arm64 / Zsh 5.9 | 通过，[环境与逐套退出码](evidence/hardening-platform.txt) | 未执行 |
| macOS 14 / arm64 | 待可用测试机或 runner | 待验证 |
| macOS 14 / x86_64 | 待可用测试机或 runner | 待验证 |
| 较新 macOS / x86_64 | 待可用测试机或 runner | 待验证 |

统一入口及命令见 [开发指南](../guides/development.md)。报告包含 UTC 时间、Git HEAD、未提交条目数量、实际 OS/build/架构/Zsh、逐套退出码和日志。报告目录必须全新；失败及中断仍写 summary。带未提交修改的记录只能代表该工作区快照，不能声称是对应 HEAD 的纯净验证。

CI 保留已有 `MACOS_TEST_RUNNERS` 配置。新增手动工作流 `platform-validation.yml` 使用 `MACOS_COMPAT_MATRIX`（对象数组），每项包括唯一 `name`、实际可用的 `runner`、期望 `os_major` 和 `arch`。runner 可以是已配置的自托管标签数组。设置期望值后会检查实际系统；标签与系统不匹配即失败，不能把新版 runner 冒充 macOS 14。未配置时仅测试默认当前 runner，并记录真实身份，不计入最低版本覆盖。

矩阵条目形状示例（必须替换成实际已配置的标签）：

```json
[{"name":"minimum-arm64","runner":["self-hosted","YOUR_MACOS14_ARM64_LABEL"],"os_major":"14","arch":"arm64"}]
```

工作流以 artifact 保存成功/失败的报告。本次不触发远程工作流、不添加或购买 runner；配置存在不代表执行通过。

## 真实环境验收单

真实安装必须在可恢复测试机执行，USB 测试使用专门测试介质。沙箱回归通过后，另建验收记录，至少包含：

- UTC 时间、操作者、硬件架构、系统版本、Git 提交或发布 tag、是否干净工作区。
- 测试机恢复方式；Homebrew/CLI 初始状态；安装来源与版本。
- 全新安装、已有安装重复执行、官方失败换源、配置修改失败恢复的实际结果与日志位置。
- Formula 安装后的版本、帮助与 dry-run；卸载/恢复结果。
- 若测试安装器或 USB：介质标识、已授权擦除的记录、创建与启动结果；未做的项目写“未验证”。

本清单不自动执行 sudo、安装或磁盘操作。现有发布工作流的真实 Formula 步骤仍独立于沙箱报告，其结果不能由本机命令桩替代。
