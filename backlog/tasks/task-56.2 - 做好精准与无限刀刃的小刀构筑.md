---
id: TASK-56.2
title: 做好精准与无限刀刃的小刀构筑
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
  - docs/rules/SILENT_SHIV_BUILD.md
parent_task_id: TASK-56
priority: high
type: feature
ordinal: 102000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按固定初代来源实现精准修改既有与新生成小刀，以及无限刀刃的回合生成与先天升级。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 精准基础和升级数值、叠加与四个牌堆已有小刀的基础伤害正确。
- [ ] #2 获得精准后生成小刀、升级和抽弃刷新不重复累计伤害。
- [ ] #3 无限刀刃在正确回合时点生成小刀，升级先天与手满去向正确。
- [ ] #4 真实获取后连续战斗验证小刀构筑，并保留平台与实机缺口。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
独立子执行者核对固定来源并实现模块，主执行者负责共享核心与界面集成；定向验证后串行完整回归。用户已授权本轮隔离开发暂免认领，保持全局暂停，不提交推送合入。
<!-- SECTION:PLAN:END -->
