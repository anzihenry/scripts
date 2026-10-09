---
title: 发布操作指南
status: current
owner: project-maintainers
updated: 2026-10-10
---

# 发布操作指南

[English](releasing.en.md)

## 🚢 Release 发布

对于 GitHub Release，优先使用统一 CLI，而不是直接调用底层脚本：

```bash
./bin/macos-scripts release verify v0.5.0
./bin/macos-scripts release publish v0.5.0 --yes
```

说明：

- `release verify <tag>` 只检查 tag、`gh` 登录状态和现有 release 状态
- `release publish <tag>` 会按幂等语义创建或更新 release
- `<tag>` 支持传 `0.4.0` 或 `v0.5.0`，CLI 会自动规范化为 `v0.5.0`
- 默认自动使用 `docs/releases/<version>/README.md` 作为 release notes
- 如需自定义文案文件，可追加 `--notes-file <path>`

### 版本号单一来源

仓库根目录的 `VERSION` 文件是版本号的唯一权威来源（当前内容为 `0.5.0`）：

- `bin/macos-scripts` 的 `version` 输出与 help 头部从 `VERSION` 读取
- `bootstrap/install.sh` 本地运行时优先读取 `VERSION`（curl 管道执行时回退到内置默认值）
- `Formula/macos-scripts.rb` 安装时会将 `VERSION` 一并安装到 `libexec`
- `release verify` / `release publish` 会自动校验目标 tag 与 `VERSION` 及 `Formula` 引用版本是否一致；`publish` 在校验不通过时直接中止，避免以错误版本发布

发布新版本时，请先更新 `VERSION` 文件、`Formula/macos-scripts.rb` 中的 URL tag 与 `sha256`，再执行 `release verify` 确认一致性。

## 发布顺序

1. 更新 VERSION、CLI/bootstrap fallback、Formula URL，并建立 `docs/releases/<version>/README.md`。
2. 按[开发验证](development.md)运行完整回归并记录候选提交与结果。
3. 审阅并提交版本变更，创建和推送版本 tag；等待 release workflow 结果。
4. 从 `refs/tags/<tag>` 源码归档计算 SHA-256，回填 main 上的 Formula；不移动已经冻结的 tag。
5. 确认 Formula 实装和发布门禁通过后执行 `release publish`，记录正式地址、产物身份和发布时间。

发布清单保存在各版本目录的 `validation.md`；历史清单不证明当前已验收或正式发布。
