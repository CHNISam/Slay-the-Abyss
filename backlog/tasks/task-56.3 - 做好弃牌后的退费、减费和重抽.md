---
id: TASK-56.3
title: 做好弃牌后的退费、减费和重抽
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-25 09:05'
labels:
  - required
  - sts1
  - builds
milestone: m-4
dependencies: []
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
- [ ] #1 弃牌计数、实例减费与下一回合重置正确，虚无和回合末不误触发手动弃牌收益。
- [ ] #2 退款在伤害后检查真实弃牌历史，末敌击杀不多退能量。
- [ ] #3 Gamble先弃再抽，战术大师、本能与使用牌处置顺序正确，升级只移除消耗。
- [ ] #4 保留真实出牌、满手、NoDraw、跨回合和失败恢复证据。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
固定来源独立模块由子执行者实现；主执行者在sts-builds接共享结算、费用和UI，定向测试后串行完整回归。沿用用户本轮隔离开发认领豁免，保持全局暂停，不提交推送。
<!-- SECTION:PLAN:END -->
