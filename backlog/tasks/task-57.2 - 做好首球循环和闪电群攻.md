---
id: TASK-57.2
title: 做好首球循环和闪电群攻
status: Done
assignee:
  - Furinya
created_date: '2026-10-25 09:05'
updated_date: '2026-10-27 04:15'
labels:
  - required
  - sts1
  - builds
milestone: m-4
dependencies: []
references:
  - docs/BACKLOG-RECONCILE-20261026.md
documentation:
  - docs/rules/DEFECT_ORB_POWERS.md
parent_task_id: TASK-57
priority: medium
type: feature
ordinal: 106000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
实现Loop和Electrodynamics，核对与集中、偏差及满球唤起的真实顺序。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 基础和升级费用、层数与生成球数正确。
- [x] #2 循环与偏差按获得顺序排队，先捕获被动数值再执行失去集中。
- [x] #3 电动力闪电对全部存活敌人生效，正确保留固定伤害且不消费随机目标。
- [x] #4 末敌击杀、Dark增长、Plasma能量及失败恢复有真实出牌证据。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
本轮收口：按原验收逐项对照已合入机制，在e3a9fe2c复跑对应现有回归；关闭本地机制切片，完整卡池与平台自然玩法留父任务。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-26实际复验：defect_orb_powers 27组通过，覆盖真实出牌、首球/群攻、获得序、随机消费、末敌和失败恢复。详见docs/BACKLOG-RECONCILE-20261026.md；本轮无游戏输入、导入或完整check。完整卡池及自然平台验收留父任务。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
已合入的本地机制切片完成；e3a9fe2c现有回归复验：defect_orb_powers 27组通过，覆盖真实出牌、首球/群攻、获得序、随机消费、末敌和失败恢复。原验收四项齐备，父任务的正式入口、全池与平台实机仍保留。
<!-- SECTION:FINAL_SUMMARY:END -->
