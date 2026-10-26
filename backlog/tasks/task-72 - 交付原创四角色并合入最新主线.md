---
id: TASK-72
title: 交付原创四角色并合入最新主线
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-26 11:28'
updated_date: '2026-10-26 11:30'
due_date: '2026-10-28'
labels: []
milestone: m-4
dependencies: []
ordinal: 117000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
交付附件V4四位原创角色各75张牌，接入既有正常流程并兼容最新跨章节核心。技术与验收说明见 docs/ORIGINAL_V4.md；同候选实机缺项继续保留。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 四人完整300张卡牌及正常获取升级商店战斗结算接入生产，跨章保持角色和永久状态
- [ ] #2 最新候选完整Quality及Licenses成功并合入远端develop
- [x] #3 实机缺失和受影响范围如实记录，不把资料包或无头测试冒充游戏验收
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
保留上游跨章节和许可实现；完成合成头生产回归与当前SHA完整Quality、Licenses，按精确head合入远端develop。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
上游PR213占用了61至64及69。旧原创61/64/69已原生归档，已Done62/63原生completed后doctor修复为70/71，上游任务保持原编号。本任务承接最终业务整合。旧27cefc3在旧base4c75a31 Quality687全绿，新base e3a9fe2必须另验。冻结数值不改，PC/实体手机/GIL及12流派实机not_run。

最新e3a9fe2合成定向7/7通过，包含cross_act12组和四角色正常流程/跨章生命周期。113历史静态告警无新增；上游许可原文保留。新SHA完整Quality与Licenses待验证。
<!-- SECTION:NOTES:END -->
