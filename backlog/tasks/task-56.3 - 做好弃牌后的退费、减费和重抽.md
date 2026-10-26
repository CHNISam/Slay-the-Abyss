---
id: TASK-56.3
title: 做好弃牌后的退费、减费和重抽
status: Done
assignee:
  - Furinya
created_date: '2026-10-25 09:05'
updated_date: '2026-10-26 13:00'
labels:
  - required
  - sts1
  - builds
milestone: m-4
dependencies: []
references:
  - docs/BACKLOG-RECONCILE-20261026.md
  - docs/BACKLOG-AUDIT-20261026.md
documentation:
  - docs/rules/SILENT_DISCARD_BUILD.md
parent_task_id: TASK-56
priority: high
type: feature
ordinal: 105000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
实现Sneaky Strike、Eviscerate与Calculated Gamble，使弃牌构筑通过真实费用与结算顺序运转。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 弃牌计数、实例减费与下一回合重置正确，虚无和回合末不误触发手动弃牌收益。
- [x] #2 退款在伤害后检查真实弃牌历史，末敌击杀不多退能量。
- [x] #3 Gamble先弃再抽，战术大师、本能与使用牌处置顺序正确，升级只移除消耗。
- [x] #4 保留真实出牌、满手、NoDraw、跨回合和失败恢复证据。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
固定来源独立模块由子执行者实现；主执行者在sts-builds接共享结算、费用和UI，定向测试后串行完整回归。沿用用户本轮隔离开发认领豁免，保持全局暂停，不提交推送。

复查原弃牌引擎的失败恢复证据，并与已通过25组实际构筑回归合并核验；不重复开发现有事务。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-26在已合入e3a9fe2c对照原验收并复跑对应现有真实Combat回归，前3项已证明；本轮补齐勾选。第4项所需自然获取/组合或失败恢复的剩余证据继续保留，不Done。逐文件结果与边界见docs/BACKLOG-RECONCILE-20261026.md。

2026-10-26追加复核：silent_discard本轮19/19，通过实际抽牌失败的原图恢复、自动全弃失败、尾部抽牌队列恢复和重试；结合silent_discard_build25组与silent_tactics60组，原AC4已有证据，不再误记缺少失败恢复。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
弃牌退款、减费、重抽及事务切片完成；本轮25组实际构筑、19组弃牌引擎（含故障恢复）及60组相关战术回归通过，原4项验收齐备。
<!-- SECTION:FINAL_SUMMARY:END -->
