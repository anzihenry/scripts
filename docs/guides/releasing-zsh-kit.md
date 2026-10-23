# zsh-kit 版本与离线交付

zsh-kit 独立于 macos-scripts 版本管理。当前组件为 **0.2.0，尚未发布**；本轮没有推送、打 tag、上传或创建外部仓库。

## 版本规则

- 三段十进制版本 `major.minor.patch`，不使用前导零。
- 0.x 的次版本用于公开 API 增加、契约收紧或需要消费者审阅的迁移；补丁用于保持公开契约的修复。
- 修改组件时同步 `packages/zsh-kit/VERSION`、`CHANGELOG.md`、README 和必要的 `API.txt`。
- 组件版本、应用版本、模板生成项目的 APP_VERSION、项目 APP_KIT_VERSION 各自独立。升级依赖只更新 APP_KIT_VERSION 和 vendor。

## 交付顺序

1. 审阅 API 和变更记录，按 [开发指南](development.md) 执行完整回归，记录平台覆盖与缺口。
2. 提交组件源码。组件目录必须干净，所有发布文件必须已跟踪；ignored 文件也不能偷偷进入发布包。
3. 静态检查：`zsh tools/package_zsh_kit.sh --check packages/zsh-kit`。
4. 生成新目录产物（目标必须不存在）：

   ```sh
   ZSH_KIT_SOURCE_URL=https://github.com/anzihenry/scripts \
     zsh tools/package_zsh_kit.sh --build packages/zsh-kit /path/to/artifacts/zsh-kit-0.2.0
   ```

5. 对产物运行开发指南中的独立包验证，再审阅 `.zsh-kit-manifest`，确认版本、来源 revision、source_dirty=false 和逐文件摘要。
6. 由消费者显式 diff/sync，更新 APP_KIT_VERSION 并运行自己的测试。提交 vendor 清单及变更。发布/tag/上传是后续单独操作。

产物是无需 Git 或网络即可使用的目录，不依赖原仓库。相同源提交生成的 payload 摘要及清单相同；不承诺目录 mtime、inode 或压缩归档字节相同。工具不会执行待打包组件代码，测试由验证步骤显式运行。

来源 URL 默认取 Git origin；包含本地 SSH 别名时，应通过 `ZSH_KIT_SOURCE_URL` 指定已确认的可访问地址。禁止把认证信息写入 URL。清单只能证明记录内容与文件摘要一致，不是发布者签名；来源真实性依靠可信仓库及审阅。

清单校验同时检查 format、版本与 VERSION 一致性、revision/dirty 字段格式和所有 payload 摘要。通用 sync 允许明确标记的 dirty/unversioned 本地开发快照；发布构建器要求已提交源码，并在复制后复核 HEAD 和干净状态。构建期间源变化时，工具返回失败且明确禁止发布该产物。

## 消费者与回退

示例当前 vendor 来自组件 0.2.0 的干净提交。`tests/fixtures/vendor/zsh-kit-0.1.0` 是不可修改的旧消费者基线，不用于新项目。两者的用途不同，不能为了通过测试直接改写基线。

同步工具和 `scripts/lib/artifact_runtime.sh` 一起升级。同步期间停止运行消费者；异常时检查报告的备份路径。正常回退可通过 Git 恢复整个 vendor 和 APP_KIT_VERSION 的同一提交，不只改 VERSION 文件。重新启动进程后再验证，不支持热升级。
