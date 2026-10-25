---
id: TASK-57.2
title: 做好首球循环和闪电群攻
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
  - docs/rules/DEFECT_ORB_POWERS.md
parent_task_id: TASK-57
priority: high
type: feature
ordinal: 106000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
实现Loop和Electrodynamics，核对与集中、偏差及满球唤起的真实顺序。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 基础和升级费用、层数与生成球数正确。
- [ ] #2 循环与偏差按获得顺序排队，先捕获被动数值再执行失去集中。
- [ ] #3 电动力闪电对全部存活敌人生效，正确保留固定伤害且不消费随机目标。
- [ ] #4 末敌击杀、Dark增长、Plasma能量及失败恢复有真实出牌证据。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
固定来源独立模块由子执行者实现；主执行者在sts-builds接共享结算、费用和UI，定向测试后串行完整回归。沿用用户本轮隔离开发认领豁免，保持全局暂停，不提交推送。
<!-- SECTION:PLAN:END -->
