---
id: TASK-20
title: 保存发布版本、更新说明和投稿凭证
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-22 13:48'
updated_date: '2026-10-27 09:21'
due_date: '2026-10-30'
labels: []
milestone: m-0
dependencies:
  - TASK-6
references:
  - docs/backlog-details/TASK-20.md
  - docs/DELIVERY-CLOSEOUT.md
priority: medium
ordinal: 20000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
让玩家能查看当前版本说明和可追溯的历史源码更新；源码记录与已确认平台发布明确区分。真实发布后保存对应代码、构建和发布凭证；Alpha测试与正式参赛作品分开记录。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 版本提案只在准备实际发布时生成，日常合并和 CI 不创建 Tag 或 Release。
- [ ] #2 Alpha 使用 0.x.x，正式参赛首发目标为 v1.0.0；真实发布记录与交付的版本、代码和更新说明一致。
- [ ] #3 主菜单能打开更新公告、查看可追溯源码版本历史并关闭返回；源码版本日期与已确认平台发布日期清晰区分，缺少发布凭证不冒称已上线。
- [ ] #4 更新版本说明后，构建内公告同步更新；相关测试及当前 PR 的 CI 通过。
- [ ] #5 实际发布成功后保存作品与投稿凭证，并在已验收的交付提交上创建不可移动的注释 Tag。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 复用指定 release-please / git-workflow Skill，采用手动版本提案与 CHANGELOG，日常提交不自动发布。
2. 按用户2026-10-27 08:40 UTC新授权，允许基于真实提交补可追溯源码版本历史；CHANGELOG为唯一正文，真实平台发布凭证保持独立，不虚构上线日期。
3. 验证版本一致性、公告交互、构建更新和相关 CI，经 PR 合入 develop。
4. 实际平台发布与投稿仍由用户完成；正式参赛首发目标 v1.0.0，当前不修改 master、不实际发布游戏。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-27 用户明确要求沿用 TASK-20 补齐版本管理及游戏内公告。旧 v0.1.0 正式首发约定被 v1.0.0 目标替代；现有 package 0.1.0 仅为代码基线，不是已发布证据。TASK-6 依赖保留用于实际投稿归档；不阻塞用户已授权的离线工具/UI实现，实际发布验收项保持未完成。

同步已合入的 PR #241 优先级和 PR #240 卡牌布局：本任务保留 Medium，不改动已有优先级队列；公告主题增量与卡牌 30/64 布局同时保留。

2026-10-27 本地实现：手动 Release Please 提案（不自动 Tag/Release）、CHANGELOG 单一公告正文、空的真实发布凭证、原生菜单公告与完整分页已接通。同步 develop 00229c1 的 PR #240/#241 后，389 项相关 Node/真实 Lua 桥接检查全通过；构建、语法、架构（145 模块/716 边）、固定 Luacheck（无新增诊断）与 Backlog 校验通过。独立审查修复已发布版本重用和最终音频构建标识/回执绑定缺口。完整当前 PR CI、原生导入/实机显示与真实发布仍分别待证据，不宣称任务全部完成。

2026-10-27 08:40 UTC用户明确更新约定：可以补版本历史以服务新增公告功能，让玩家看到每个版本更新内容。此前禁止回补源码历史的约束被此授权替代；不代表授权伪造平台发布或报名。PR247的14个源码SHA、北京时间日期、相邻祖先关系及主要说明已独立核对；精确HEAD f09549a29ae32f87120af6f6b92de3ca320ab360的Quality40475735096全部7作业和Licenses40475734951成功，已合入develop fa93ac9ff23e7e5cbcf74813d1f9fa776219a314。当前源码版本基线0.10.1，历史v0.1.0至v0.10.1；publications.json仍为空真实发布账本，不把源码版本日期当上线日期。现有vX.Y.Z、Alpha0.x、正式参赛v1.0.0、手动提案且不自动发布流程保留。原生导入/实机交互及实际平台发布/投稿仍待用户执行与验收，未关闭整项任务。
<!-- SECTION:NOTES:END -->
