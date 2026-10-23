# 开发与升级

运行 `zsh tests/run.sh` 验证语法、vendor 摘要、公共组件契约、帮助/版本无副作用和示例命令。

离线升级公共库：

1. 获取并审阅可信源版本，保持源工作区干净。
2. `zsh scripts/vendor_zsh_kit.sh --diff /path/to/zsh-kit vendor/zsh-kit` 查看差异；有差异返回 1。
3. `zsh scripts/vendor_zsh_kit.sh --sync /path/to/zsh-kit vendor/zsh-kit` 更新，已有本地改动会被拒绝覆盖。
4. 更新 `project.conf` 的 `APP_KIT_VERSION`，执行 `zsh tests/run.sh` 和业务测试，一起提交 vendor 清单及差异。

新进程加载新组件，禁止运行时升级。版本 0.x 次版本变化需审阅兼容性；补丁版本保留公开接口。源版本、dirty 状态和逐文件摘要记录于 vendor 的 `.zsh-kit-manifest`；源 revision 未知时明确标为 unversioned，不能当作可追溯发布。

共享资源锁保留历史协议目录名以协调旧项目，详情见 `vendor/zsh-kit/README.md`；它不决定本项目的日志、配置或命令名称。
