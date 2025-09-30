---
name: Maintenance 脚本更新
about: 调整 `maintain/` 下的日常维护或批量操作脚本
title: "[maintain] "
labels: ["maintain"]
---

## 摘要
- 说明新增/修改的维护流程及触发场景。
- 链接相关 Issue、告警或运维记录。

## 变更范围
- [ ] 新增维护脚本
- [ ] 优化批量任务（循环、重试、并发控制等）
- [ ] 改动日志/输出格式
- [ ] 更新依赖或环境假设
- [ ] 其他（请补充）

## 验证 Checklist
- [ ] `./lint/lint_shell.sh`
- [ ] `bash -n <script_path>`
- [ ] Dry-run / `--dry-run` 日志
- [ ] 实际运行关键分支（含失败重试路径）
- [ ] 生成/更新的报告或日志附件
- [ ] 其他验证：

> 勾选并填写每项验证的结论与耗时。若某项暂未完成，请注明计划时间。

## 风险评估
- 潜在影响面：
- 回滚步骤（例如恢复旧脚本或清理产生的文件）：
- 监控与告警：

## 额外说明
- 是否影响 `brew_update_errors.log` 或其他公共输出？
- 是否需 Changelog / README 更新？
