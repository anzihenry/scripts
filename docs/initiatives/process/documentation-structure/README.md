---
title: 文档结构迁移
status: completed
owner: project-maintainers
updated: 2026-10-10
---

# 文档结构迁移

[English](README.en.md)

状态：completed，负责人：project-maintainers。唯一任务状态源为本文。

## 目标与范围

沿用 HarnessBrew 按职责组织文档的目录结构，拆分根 README，迁移重构历史与版本记录，更新发布 CLI、帮助、测试和包装引用。直接采用新路径，不保留兼容跳转。

## 完成条件

- 原有文档内容可通过新索引访问，旧目录无维护文件。
- 仓库本地链接有效，默认 release notes 从新目录读取。
- 语法、lint、smoke、guard 和 E2E 通过。

## 导航

[文档地图](../../../README.md)、[组织约定](../../../documentation.md)、[验证记录](validation.md)。

根 README、CHANGELOG 和 docs 文档已补充英文配对。HarnessBrew 的独立评审治理体系尚未接入。

## 交付结果

目录迁移、引用更新和默认发布路径切换完成，本地链接及完整回归通过，见[验证记录](validation.md)。当前变更尚未提交；远端发布状态核实不影响结构迁移，后续由维护者补充版本证据。
