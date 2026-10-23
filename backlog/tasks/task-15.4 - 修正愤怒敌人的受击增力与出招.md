---
id: TASK-15.4
title: 修正愤怒敌人的受击增力与出招
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-23 20:44'
labels: []
dependencies: []
parent_task_id: TASK-15
priority: high
type: bug
ordinal: 63000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
修复已可玩mad_gremlin的固定血量与自创增力回合，按固定来源实现20–24血量、每回合攻击4、正常攻击穿透格挡后触发Angry1；排除药水、毒和反伤，保持多段/范围攻击队列与死亡边界。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 固定来源核对血量、攻击、开场roll与Angry触发/队列顺序，并记录精确身份
- [ ] #2 真实Combat/Run先失败再通过，覆盖格挡、多段、范围伤害、反伤死亡、Artifact、排除伤害类型与回滚
- [ ] #3 数据/完整回归、独立评审和当前SHA正式CI通过，原版分流随机及平台未验边界保留
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
核对源链与所有权；真实入口负例；最小敌人数据/反应/AI/schema修复；独立评审及正式CI后集成。
<!-- SECTION:PLAN:END -->
