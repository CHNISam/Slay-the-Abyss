---
id: TASK-16.3
title: 做好腐化与消耗触发的构筑联动
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-25 08:14'
updated_date: '2026-10-27 15:04'
labels:
  - required
  - sts1
  - builds
milestone: m-4
dependencies: []
references:
  - docs/BACKLOG-RECONCILE-20261026.md
documentation:
  - docs/rules/WARRIOR_EXHAUST_BUILD.md
parent_task_id: TASK-16
priority: medium
type: feature
ordinal: 104000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
补齐腐化、无惧疼痛、黑暗之拥和哨卫的费用与消耗触发，供燃烧契约和坚毅等牌共用。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 腐化费用变化保留原版不可打出和X费用限制，技能消耗优先级正确。
- [x] #2 无惧疼痛与黑暗之拥按获得顺序排队，哨卫能量先于队尾抽牌。
- [x] #3 消耗所选牌与使用牌自身消耗分开触发，抽牌不会提前抽回正在使用的牌。
- [x] #4 死亡、末敌击杀与失败恢复有真实牌证据，不以模块测试代替共享接入。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
本轮收口：按原验收逐项对照已合入机制，在e3a9fe2c复跑对应现有回归；关闭本地机制切片，完整卡池与平台自然玩法留父任务。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-26实际复验：corruption_cost 21、warrior_exhaust_cards 25、warrior_exhaust_endturn 11、end_turn_discard_order 4及warrior_exhaust全部通过，覆盖真实出牌、顺序、死亡和失败恢复。详见docs/BACKLOG-RECONCILE-20261026.md；本轮无游戏输入、导入或完整check。完整卡池及自然平台验收留父任务。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
已合入的本地机制切片完成；e3a9fe2c现有回归复验：corruption_cost 21、warrior_exhaust_cards 25、warrior_exhaust_endturn 11、end_turn_discard_order 4及warrior_exhaust全部通过，覆盖真实出牌、顺序、死亡和失败恢复。原验收四项齐备，父任务的正式入口、全池与平台实机仍保留。
<!-- SECTION:FINAL_SUMMARY:END -->
