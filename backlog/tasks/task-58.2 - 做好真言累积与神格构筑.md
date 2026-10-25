---
id: TASK-58.2
title: 做好真言累积与神格构筑
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-25 08:14'
updated_date: '2026-10-25 08:18'
labels:
  - required
  - sts1
  - builds
milestone: m-4
dependencies: []
documentation:
  - docs/rules/WATCHER_MANTRA.md
parent_task_id: TASK-58
priority: high
type: feature
ordinal: 103000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
实现伏身、礼拜和供奉，核对真言、神格能量与姿态联动的原版顺序。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 伏身、礼拜和供奉的费用、数值、升级与保留正确。
- [ ] #2 真言达到阈值的移除、余数、神格姿态和能量按原版顺序结算。
- [ ] #3 供奉在下次自身回合抽牌后触发，神格退出与再次进入正确。
- [ ] #4 真实牌与连续战斗覆盖构筑，特殊大层数与未验证交互明确记录。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
独立子执行者核对固定来源并实现模块，主执行者负责共享核心与界面集成；定向验证后串行完整回归。用户已授权本轮隔离开发暂免认领，保持全局暂停，不提交推送合入。
<!-- SECTION:PLAN:END -->
