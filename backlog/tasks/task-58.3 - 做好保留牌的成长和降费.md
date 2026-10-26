---
id: TASK-58.3
title: 做好保留牌的成长和降费
status: Done
assignee:
  - Furinya
created_date: '2026-10-25 09:05'
updated_date: '2026-10-26 12:06'
labels:
  - required
  - sts1
  - builds
milestone: m-4
dependencies: []
references:
  - docs/BACKLOG-RECONCILE-20261026.md
documentation:
  - docs/rules/WATCHER_RETAIN_BUILD.md
parent_task_id: TASK-58
priority: high
type: feature
ordinal: 107000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
实现Protect、Perseverance、Windmill Strike和Sands of Time，使用真实保留阶段与实例历史。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 基础和升级数值、费用及保留行为正确。
- [x] #2 成长发生于回合末恢复保留牌阶段，使用或主动弃牌不成长。
- [x] #3 升级保留已有成长历史，降费读取当前费用且最低为零。
- [x] #4 虚无、腐化、满手、跨战重建及失败恢复明确验证或保留缺口。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
本轮收口：按原验收逐项对照已合入机制，在e3a9fe2c复跑对应现有回归；关闭本地机制切片，完整卡池与平台自然玩法留父任务。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-26实际复验：watcher_retain_build 21组及end_turn_discard_order 4组通过，覆盖真实回合成长/减费、腐化、满手及完整图恢复。详见docs/BACKLOG-RECONCILE-20261026.md；本轮无游戏输入、导入或完整check。完整卡池及自然平台验收留父任务。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
已合入的本地机制切片完成；e3a9fe2c现有回归复验：watcher_retain_build 21组及end_turn_discard_order 4组通过，覆盖真实回合成长/减费、腐化、满手及完整图恢复。原验收四项齐备，父任务的正式入口、全池与平台实机仍保留。
<!-- SECTION:FINAL_SUMMARY:END -->
