---
id: TASK-20
title: 保存发布版本、更新说明和投稿凭证
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-22 13:48'
updated_date: '2026-10-28 05:05'
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
让玩家通过千星奇域官方更新日志查看更新；游戏主菜单只保留简洁当前版本号。保存可追溯源码版本、更新说明及真实发布后的代码、构建和投稿凭证，Alpha测试与正式参赛作品分开记录。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 版本提案只在准备实际发布时生成，日常合并和 CI 不创建 Tag 或 Release。
- [ ] #2 Alpha 使用 0.x.x，正式参赛首发目标为 v1.0.0；真实发布记录与交付的版本、代码和更新说明一致。
- [ ] #3 游戏内不再提供自研更新公告入口、弹窗、历史切换或分页，主菜单保留当前版本号且不展示 Git SHA。
- [ ] #4 CHANGELOG 保留玩家文案供人工填写官方奇域信息更新日志；版本与发布凭证校验保留，菜单、退出、手柄和触控相关测试及当前 PR 的 CI 通过。
- [ ] #5 实际发布成功后保存作品与投稿凭证；新正式版本 Tag 在内容冻结、必要验证与候选交付后才创建，既有 14 个 Tag 不移动、不删除、不覆盖。
- [ ] #6 版本文档记录用户决定及四点理由，不新建公告系统、自动同步工具、额外后台或营销页面；不把决策当作历史发布证据。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 按2026-10-28用户决定，以最新develop独立工作树删除自研公告布局、宿主分支、专用模块/主题/测试，只保留菜单版本号。
2. 保留CHANGELOG、版本一致性校验、候选溯源与真实publication账本；复用既有v0.11.0提案，不新建版本算法或Tag。
3. 更新版本索引和发布操作单，记录官方奇域信息更新日志、潜在更新速报曝光不保证、减少重复维护以及集中参赛玩法投入。
4. 串行验证版本、构建、菜单/退出/手柄/触控，再交根线程创建PR并按精确HEAD完整Quality集成；官方导入/实机/真实发布独立留待证据。
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

2026-10-28用户明确取消游戏内自研更新公告，旧公告UI与开发透明面板验收由本轮正式替代。复用TASK-20，不关闭实际发布/投稿验收。独立工作树remove-release-announcements基于develop 5a27fea79ba9d33ca5486b8fc6044a98ab81d41b；本轮不改玩法、地图、存档或已有14个Tag。

2026-10-28公告移除切片离线验证：266项相关Node检查全部通过、0失败/0跳过，覆盖release-notes版本/出版证据、候选source/notes hash、最终audio/BGM溯源、菜单真实Lua宿主和构建输入保护。另5个原始Lua夹具controller_host/controller_current/game_ui_exit/game_ui_exit_swipe/game_ui_battle_speed_gestures串行通过，native-startup/ui-mock合同2项通过。所有非公告原生控件与develop 5a27fea逐值一致（仅移除公告面板及菜单入口），菜单版本标签样式/位置保持。build:data/build:ui、JS语法、Backlog、架构213模块/1235边和固定Luacheck通过：无新增诊断、84条历史警告、418个受控测量达标。仅离线，无完整Quality、官方导入/实机或真实发布证据，AC未勾选，任务保持In Progress；随后接入PR276版本提案并重验组合。
<!-- SECTION:NOTES:END -->
