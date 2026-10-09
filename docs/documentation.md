---
title: 文档组织约定
status: current
owner: project-maintainers
updated: 2026-10-10
---

# 文档组织约定

[English](documentation.en.md)

本项目采用 HarnessBrew 的职责分类，按规模裁剪。中文为主版本，根 README、CHANGELOG 和 docs 文档提供 `.en.md` 英文配对；独立评审治理体系尚未接入。

| 位置 | 职责 |
| --- | --- |
| 根 README | 用途、环境、最短示例与导航 |
| 根 CHANGELOG | 版本摘要，链接版本记录 |
| docs/README | 按读者需求组织的文档地图 |
| guides | 可重复执行的使用、开发、运维与发布步骤 |
| engineering | 当前架构与模块约束 |
| planning | 跨专题优先级与规划规则 |
| initiatives/<分类>/<主题> | 一次具体工作的过程、状态与证据 |
| releases/<版本> | 版本说明、验证与发布证据 |

只创建有内容的目录，每个领域提供 README 导航。专题按 feature、improvement、refactor、research、process 分类；历史通过状态与索引表达，不另外建立 archive 分类。

## 元信息与责任

正式文档维护 title、status、owner、updated 元信息。project-maintainers 指本仓库维护者。长期文档使用 current/draft/superseded，专题使用 proposed/active/paused/completed/cancelled，发布使用 planned/verified/released/cancelled/withdrawn。历史原始材料可保留原格式，由入口说明语境。

测试命令仅在[开发与验证](guides/development.md)维护。专题状态仅在专题 README 维护。发布状态须有证据，不能仅凭 VERSION 或发布草稿判断已发布；目前历史发布状态待核实，统一标为 planned 并在版本入口说明。

## 链接与检查

仓库内使用相对链接，移动文件必须同步更新调用方与包装配置。中文和英文互链，英文导航优先链接英文文件；技术路径、命令和历史日志保持原始内容。两种语言的 owner/status 一致，updated 记录各自实质更新日期；后续内容改动须同步两种语言。

当前检查通过迁移验证记录中的本地链接、元信息、语言配对检查和脚本回归完成；未接入专门文档 CI 或独立评审强制门槛。维护者每 90 天复核 current 文档；大型日志和候选包留在外部或 Git 忽略目录。
