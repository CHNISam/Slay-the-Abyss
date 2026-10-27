---
id: TASK-20
title: 保存发布版本、更新说明和投稿凭证
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-22 13:48'
updated_date: '2026-10-27 09:59'
due_date: '2026-10-30'
labels: []
milestone: m-0
dependencies:
  - TASK-6
references:
  - docs/backlog-details/TASK-20.md
  - docs/DELIVERY-CLOSEOUT.md
  - docs/versions/README.md
priority: medium
ordinal: 20000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
让玩家能查看当前版本说明和已确认的历史更新。真实发布后保存对应代码、构建和发布凭证；Alpha 测试与正式参赛作品分开记录。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 版本提案只在准备实际发布时生成，日常合并和 CI 不创建 Tag 或 Release。
- [ ] #2 Alpha 使用 0.x.x，正式参赛首发目标为 v1.0.0；真实发布记录与交付的版本、代码和更新说明一致。
- [ ] #3 主菜单能打开更新公告、查看历史并关闭返回；没有发布记录时如实显示空状态。
- [x] #4 更新版本说明后，构建内公告同步更新；相关测试及当前 PR 的 CI 通过。
- [ ] #5 实际发布成功后保存作品与投稿凭证，并在已验收的交付提交上创建不可移动的注释 Tag。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 复用指定 release-please / git-workflow Skill，采用手动版本提案与 CHANGELOG。
2. 由同一说明源构建原生公告；已确认历史只读取真实发布凭证。
3. 验证版本一致性、公告交互、构建更新和相关 CI，经 PR 合入 develop。
4. 实际平台发布与投稿仍由用户完成；本轮不修改 master、不创建发布或补造历史。

2026-10-27 收尾：复核PR247最新HEAD完整Quality/Licenses与实际合入提交；核对14个历史日期/源码并创建不可覆盖注释Tag；固定索引、遍历实际14版公告，平台实机与发布凭证继续单独待验。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-27 用户明确要求沿用 TASK-20 补齐版本管理及游戏内公告。旧 v0.1.0 正式首发约定被 v1.0.0 目标替代；现有 package 0.1.0 仅为代码基线，不是已发布证据。TASK-6 依赖保留用于实际投稿归档；不阻塞用户已授权的离线工具/UI实现，实际发布验收项保持未完成。

同步已合入的 PR #241 优先级和 PR #240 卡牌布局：本任务保留 Medium，不改动已有优先级队列；公告主题增量与卡牌 30/64 布局同时保留。

2026-10-27 本地实现：手动 Release Please 提案（不自动 Tag/Release）、CHANGELOG 单一公告正文、空的真实发布凭证、原生菜单公告与完整分页已接通。同步 develop 00229c1 的 PR #240/#241 后，389 项相关 Node/真实 Lua 桥接检查全通过；构建、语法、架构（145 模块/716 边）、固定 Luacheck（无新增诊断）与 Backlog 校验通过。独立审查修复已发布版本重用和最终音频构建标识/回执绑定缺口。完整当前 PR CI、原生导入/实机显示与真实发布仍分别待证据，不宣称任务全部完成。

2026-10-27：PR247最新HEAD f09549a29ae32f87120af6f6b92de3ca320ab360的Licenses inventory与Quality四分片/presentation/engineering-posix/check全部SUCCESS，已squash合入develop fa93ac9ff23e7e5cbcf74813d1f9fa776219a314。按索引核对14节点祖先关系和北京时间日期，原子推送14个注释源码Tag，远端逐个peeled SHA读回匹配；v0.10.1固定fa93ac9，不移动旧Tag。版本与Milestone分开。公告/发布溯源专项38项：32通过、0失败、6项Windows符号链接权限跳过；真实Lua宿主9组包括实际14版本前后切换、逐页往返、关闭重开与旧输入隔离。先前缺构建数据的失败已补build:data后重跑通过。仅离线，不是平台实机；AC3等待千星奇域导入与本轮日志/截图，AC2/5等待真实发布凭证，任务保持In Progress。

PR249评审修正：负责人按现行AGENTS保持Furinya。实际14版宿主遍历增加新增/优化/修复正文、空尾行的逐版双向核对；保留原长Unicode分页测试与历史授权记录，不触碰PR250在途修改。
<!-- SECTION:NOTES:END -->
