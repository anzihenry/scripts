---
title: 发布操作指南
status: current
owner: project-maintainers
updated: 2026-10-10
---

# 发布操作指南

[English](releasing.en.md)

## 🚢 Release 发布

发布属于仓库维护流程，由 `.github/workflows/release.yml` 编排，不属于安装后的 `macos-scripts` 功能。复杂逻辑位于 `tools/release/`，不会随 Formula 安装。维护者可在仓库根目录本地排查：

```bash
zsh tools/release/release.sh verify v0.5.0
zsh tools/release/release.sh publish v0.5.0 --yes
```

说明：

- `release verify <tag>` 严格检查版本一致性、tag、`gh` 登录状态和现有 release 状态；版本不一致立即失败
- `release publish <tag>` 会按幂等语义创建或更新 release
- `<tag>` 支持传 `0.5.0` 或 `v0.5.0`，内部工具会规范化为 `v0.5.0`
- 默认自动使用 `docs/releases/<version>/README.md` 作为 release notes
- 如需自定义文案文件，可追加 `--notes-file <path>`

### 版本号单一来源

仓库根目录的 `VERSION` 文件是版本号的唯一权威来源（当前内容为 `0.5.0`）：

- `bin/macos-scripts` 的 `version` 输出与 help 头部从 `VERSION` 读取
- `bootstrap/install.sh` 本地运行时优先读取 `VERSION`（curl 管道执行时回退到内置默认值）
- `Formula/macos-scripts.rb` 安装时会将 `VERSION` 一并安装到 `libexec`
- `release verify` / `release publish` 会自动校验目标 tag 与 `VERSION` 及 `Formula` 引用版本是否一致；两者在校验不通过时均直接中止，避免以错误版本发布

发布新版本时，请先更新 `VERSION` 文件、`Formula/macos-scripts.rb` 中的 URL tag 与 `sha256`，再执行 `release verify` 确认一致性。

## 发布顺序

1. 更新 VERSION、CLI/bootstrap fallback、Formula URL，并建立 `docs/releases/<version>/README.md`。
2. 按[开发验证](development.md)运行完整回归并记录候选提交与结果。
3. 审阅并提交版本变更，创建和推送版本 tag；等待 release workflow 结果。
4. 从 `refs/tags/<tag>` 源码归档计算 SHA-256，回填 main 上的 Formula；不移动已经冻结的 tag。
5. 回填后重新运行 release workflow，手动运行必须提供明确 tag。工作流校验 tag 对应源码、tap Formula URL 和安装后的精确版本；全部通过后由 publish job 创建或更新 GitHub Release。记录正式地址、产物身份和发布时间。

发布清单保存在各版本目录的 `validation.md`；历史清单不证明当前已验收或正式发布。
