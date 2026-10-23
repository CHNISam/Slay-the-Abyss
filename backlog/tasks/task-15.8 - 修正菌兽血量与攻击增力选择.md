---
id: TASK-15.8
title: 修正菌兽血量与攻击增力选择
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-23 22:31'
labels: []
dependencies: []
parent_task_id: TASK-15
priority: high
type: bug
ordinal: 67000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
仅修复已有fungi_beast的22–28血量、60/40攻击/增力选择及禁止三连攻击/连续增力，保留攻击6与力量3。核对开场和行动后roll。死亡孢子云仍是父任务未完成项，不把此切片称完整菌兽实现。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 固定来源明确血量、60/40边界、历史限制与RollMove规则，来源身份可复核
- [ ] #2 真实Combat/Run先失败再通过，覆盖抽样顺序、决策历史、反伤死亡同伴/末敌边界及现有数值
- [ ] #3 数据/受影响回归、独立评审及当前SHA CI通过；死亡孢子云、完整随机流/平台和父任务边界保留
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
源码核对；真实入口红例；最小HP/AI/data/schema修复；独立评审及正式CI后集成。
<!-- SECTION:PLAN:END -->
