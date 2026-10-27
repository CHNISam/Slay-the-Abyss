---
id: TASK-20
title: 保存发布版本、更新说明和投稿凭证
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-22 13:48'
updated_date: '2026-10-27 17:21'
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
- [ ] #6 公告内有简洁开发透明与非商用许可说明；仓库地址仅在官方规则证据足够时展示，原公告翻页、历史切换、关闭及输入隔离保持可用。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 复用指定 release-please / git-workflow Skill，采用手动版本提案与 CHANGELOG，日常提交不自动发布。
2. 按用户2026-10-27 08:40 UTC新授权，允许基于真实提交补可追溯源码版本历史；CHANGELOG为唯一正文，真实平台发布凭证保持独立，不虚构上线日期。
3. 验证版本一致性、公告交互、构建更新和相关 CI，经 PR 合入 develop。
4. 实际平台发布与投稿仍由用户完成；正式参赛首发目标 v1.0.0，当前不修改 master、不实际发布游戏。

2026-10-27开发透明小切片：在既有公告面板内加入静态开发信息，沿用主题与分页；核对LICENSE和官方地址规则后保守展示，补公告布局、原生宿主交互及构建检查。不改玩法、数值、版本号、Tag或发布流程。

按用户最终确认，仅将开发透明区介绍改为“代码已公开到开源社区。”，保持无地址/邀约、原布局和准确非商用许可；同步精确断言并串行重跑公告宿主。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-27 用户明确要求沿用 TASK-20 补齐版本管理及游戏内公告。旧 v0.1.0 正式首发约定被 v1.0.0 目标替代；现有 package 0.1.0 仅为代码基线，不是已发布证据。TASK-6 依赖保留用于实际投稿归档；不阻塞用户已授权的离线工具/UI实现，实际发布验收项保持未完成。

同步已合入的 PR #241 优先级和 PR #240 卡牌布局：本任务保留 Medium，不改动已有优先级队列；公告主题增量与卡牌 30/64 布局同时保留。

2026-10-27 本地实现：手动 Release Please 提案（不自动 Tag/Release）、CHANGELOG 单一公告正文、空的真实发布凭证、原生菜单公告与完整分页已接通。同步 develop 00229c1 的 PR #240/#241 后，389 项相关 Node/真实 Lua 桥接检查全通过；构建、语法、架构（145 模块/716 边）、固定 Luacheck（无新增诊断）与 Backlog 校验通过。独立审查修复已发布版本重用和最终音频构建标识/回执绑定缺口。完整当前 PR CI、原生导入/实机显示与真实发布仍分别待证据，不宣称任务全部完成。

2026-10-27 08:40 UTC用户明确更新约定：可以补版本历史以服务新增公告功能，让玩家看到每个版本更新内容。此前禁止回补源码历史的约束被此授权替代；不代表授权伪造平台发布或报名。PR247的14个源码SHA、北京时间日期、相邻祖先关系及主要说明已独立核对；精确HEAD f09549a29ae32f87120af6f6b92de3ca320ab360的Quality40475735096全部7作业和Licenses40475734951成功，已合入develop fa93ac9ff23e7e5cbcf74813d1f9fa776219a314。当前源码版本基线0.10.1，历史v0.1.0至v0.10.1；publications.json仍为空真实发布账本，不把源码版本日期当上线日期。现有vX.Y.Z、Alpha0.x、正式参赛v1.0.0、手动提案且不自动发布流程保留。原生导入/实机交互及实际平台发布/投稿仍待用户执行与验收，未关闭整项任务。

2026-10-27：PR247最新HEAD f09549a29ae32f87120af6f6b92de3ca320ab360的Licenses inventory与Quality四分片/presentation/engineering-posix/check全部SUCCESS，已squash合入develop fa93ac9ff23e7e5cbcf74813d1f9fa776219a314。按索引核对14节点祖先关系和北京时间日期，原子推送14个注释源码Tag，远端逐个peeled SHA读回匹配；v0.10.1固定fa93ac9，不移动旧Tag。版本与Milestone分开。公告/发布溯源专项38项：32通过、0失败、6项Windows符号链接权限跳过；真实Lua宿主9组包括实际14版本前后切换、逐页往返、关闭重开与旧输入隔离。先前缺构建数据的失败已补build:data后重跑通过。仅离线，不是平台实机；AC3等待千星奇域导入与本轮日志/截图，AC2/5等待真实发布凭证，任务保持In Progress。

PR249评审修正：负责人按现行AGENTS保持Furinya。实际14版宿主遍历增加新增/优化/修复正文、空尾行的逐版双向核对；保留原长Unicode分页测试与历史授权记录，不触碰PR250在途修改。

本轮从GitHub核实develop ac8cc52454db85939ee131ece85bfd421af7b7bd，在独立feat/source-transparency工作树实施；负责人Furinya。LICENSE为PolyForm Noncommercial License 1.0.0，不称完全开源。地址规则正在独立核实，未确认前不写入可发布候选。TASK-20原有平台与发布验收保持未完成。

开发透明小切片离线验收：主菜单→更新公告底部两行静态信息，正文每页五行且不裁切；PolyForm Noncommercial 1.0.0与根LICENSE一致。官方守则/服务协议涉及外部引流，本例未获静态源码地址明确许可，保守省略地址与访问邀约，不声称全面禁止。build:data、build:ui、294项相关Node检查（0失败/0跳过）、JS语法和Backlog门禁通过；实际Lua宿主9组含14版全页双向、关闭重开、触控与控制器隔离。公告外全控件及既有公告按钮与ac8cc524逐值一致，新增交互0。详情见附件；当前PR完整Quality、官方导入与实机仍待，原AC不勾选、任务保持In Progress。

按用户最终确认，开发透明介绍现为“代码已公开到开源社区。”；标题与准确PolyForm非商用/第三方说明保持，无链接/邀约/替代检索线索，布局不变。build:ui及受影响公告5项检查全过、0跳过（含实际Lua宿主9组与14版完整分页/输入隔离）。旧5e6f45d候选及全部证据保留；本次仍仅离线，不关闭平台/投稿验收项。
<!-- SECTION:NOTES:END -->
