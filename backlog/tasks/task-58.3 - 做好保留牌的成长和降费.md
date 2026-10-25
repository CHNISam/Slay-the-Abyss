---
id: TASK-58.3
title: 做好保留牌的成长和降费
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
- [ ] #1 基础和升级数值、费用及保留行为正确。
- [ ] #2 成长发生于回合末恢复保留牌阶段，使用或主动弃牌不成长。
- [ ] #3 升级保留已有成长历史，降费读取当前费用且最低为零。
- [ ] #4 虚无、腐化、满手、跨战重建及失败恢复明确验证或保留缺口。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
固定来源独立模块由子执行者实现；主执行者在sts-builds接共享结算、费用和UI，定向测试后串行完整回归。沿用用户本轮隔离开发认领豁免，保持全局暂停，不提交推送。
<!-- SECTION:PLAN:END -->
