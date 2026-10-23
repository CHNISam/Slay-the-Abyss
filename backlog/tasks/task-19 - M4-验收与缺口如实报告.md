---
id: TASK-19
title: M4 验收与缺口如实报告
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 13:48'
updated_date: '2026-10-23 08:50'
due_date: '2026-10-29'
labels: []
milestone: m-5
dependencies:
  - TASK-18
  - TASK-5
  - TASK-25
priority: high
ordinal: 19000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按发布前检查表逐条核验；未完成项必须如实记录，不得宣布为通过。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 按发布前检查表逐条核验并勾选
- [ ] #2 未完成项与内容缺口如实写入报告
- [ ] #3 列出已知问题与规避说明
- [ ] #4 同一候选确认赛事资格、报名入口与作品GUID，发布前人工复核；收益已由用户确认，不重复设阻塞
- [ ] #5 发布候选核对M2/M3规则账本与M4反馈/体验验收，实际首发内容无未核实规则或未修正实质偏差才可声明严格一致；可选元素/第二幕未启用不得列缺口阻塞必选投稿。10/30准备硬线不因扩展延后。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-23 /root：仅推进不依赖原神的候选取证与缺口报告切片。固定本批source SHA和候选hash，真实MCP编译/副本构建后独立只读核对28模块同源、1590树控件/max50/六列模板与22节点结算挂载；记录完整本地/当前CI结果和仍失败的地图golden，不据此放行官方导入/实机/严格一致性或发布。BGM另用默认关闭与显式试听副本区分。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
赛事入口正式确认从TASK-1迁入本M4候选关口；不可用时不放行M5。

本轮用户明确暂不开原神、授权跨Backlog离线持续并行；TASK5/18/25依赖及所有正式发布前AC仍未满足，领取只做离线报告切片。源139de94规则候选已真实构建，独立只读报告在根.artifacts/continued-batch-139de94/readback-verification.json。不是正式发布候选放行。

PR99/100已在各自当前head两个Quality成功后合入1182814/14979df。源139de94规则副本28模块同源、1590树/max50/6列/22节点结算已启用；源cf6969e显式BGM叠加29模块同源、22+83节点两图启用、参数true。两者静态0error17warning，输入底图及候选只读前后hash相同。docs/P0-SMOKE与两份docs/evidence记录路径/hash/读回报告/源码换行口径。地图golden仍0/12，未导入/开游戏/试听/放行正式发布，所有AC未勾。
<!-- SECTION:NOTES:END -->
