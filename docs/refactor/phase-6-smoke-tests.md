# Phase 6 Smoke Tests

## 目标

补一套仓库内可直接运行的最小回归护栏，优先覆盖：

- CLI 帮助输出
- 参数校验失败路径
- 安全的 dry-run 路径

这套护栏不依赖额外测试框架，也不尝试覆盖会真正修改用户环境的 setup 安装流程。

## 入口

```bash
./tests/smoke_cli.sh
```

## 当前覆盖项

1. `macos-scripts --help`
2. `macos-scripts lint help`
3. `macos-scripts maintain brew --dry-run`
4. `macos-scripts release verify` 缺少 tag 的失败提示
5. `macos-scripts setup github --domain example.com` 的参数校验失败提示

## 设计原则

- 优先覆盖稳定、无副作用的命令入口
- 所有用例都使用临时目录覆盖：
  - `MACOS_SCRIPTS_LOG_DIR`
  - `MACOS_SCRIPTS_CONFIG_DIR`
- 不直接运行会真正安装软件或修改用户主目录配置的命令

## 暂不纳入 smoke 的项

- `setup packages`
- `setup shell`
- `setup git`
- `maintain installer list`
- `release publish/verify` 的真实远端交互

原因：

- 这些命令要么会修改环境，要么依赖网络、系统服务或外部登录状态，更适合作为手工验证项保留在阶段基线里。
