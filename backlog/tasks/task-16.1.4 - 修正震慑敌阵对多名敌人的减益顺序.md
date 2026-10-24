---
id: TASK-16.1.4
title: 修正震慑敌阵对多名敌人的减益顺序
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-24 13:04'
due_date: '2026-10-28'
labels:
  - required
milestone: m-4
dependencies:
  - TASK-16.1.3
references:
  - docs/backlog-details/TASK-16.1.md
  - docs/reviews/TASK-16-m3-card-audit.md
parent_task_id: TASK-16.1
priority: high
type: bug
ordinal: 88000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
目前先对所有敌人施加虚弱，再对所有敌人施加易伤；应按敌人顺序逐个施加两种减益。最终层数相同也不能代替正确的中间状态与反馈顺序。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 基础和升级牌都按敌人顺序先虚弱后易伤，费用、层数、消耗与原表现不变。
- [ ] #2 免疫逐次正确消耗，死亡或逃跑目标跳过；事件快照与实际状态一致。
- [ ] #3 旧无标记群体效果保持原顺序，坏分组在本次效果副作用前拒绝，合法出牌失败完整回滚。
- [ ] #4 固定来源、真实入口、状态帧、文案与详情回归通过独立评审及当前CI；平台实测单独记录。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
已用30真实入口复现22多活敌顺序/快照负例并核固定来源。保留两条平铺applyStatusAll与现有表现索引，用受限显式targetGroup=weak_then_vulnerable两项组实现逐敌执行，schema与supported校验局部组，apply仅预检新标记而不改变无标记旧错误时机。保持共享Actor、Run、RNG及现有死敌/源死亡/末敌清理和出牌事务。先红后绿，独立评审后按当前CI交付。
<!-- SECTION:PLAN:END -->
