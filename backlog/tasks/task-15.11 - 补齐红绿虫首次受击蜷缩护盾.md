---
id: TASK-15.11
title: 补齐红绿虫首次受击蜷缩护盾
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-23 23:32'
labels: []
dependencies: []
parent_task_id: TASK-15
priority: high
type: bug
ordinal: 70000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按固定来源加入红绿虫开场3–7蜷缩值，首次非致死普通攻击造成生命损失时只触发一次。格挡与移除被动排在当前动作队尾，不在同卡多段之间提前获得格挡；保留死亡/队列/原子回滚边界。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 固定来源明确开场构造/洗牌/被动抽样顺序、一次锁定与队尾GainBlock/Remove规则
- [ ] #2 真实Combat/Run先失败再通过，覆盖多段/反伤/玩家与敌人死亡、毒药水排除、重复触发、队尾顺序与回滚
- [ ] #3 状态说明图标与数据/相关回归、独立评审和当前SHA CI通过；完整队列/分流随机/平台和父任务边界保留
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
独立核对源码和队尾契约；真实红例；最小事务内尾队列及被动修复；独立评审及正式CI后集成。
<!-- SECTION:PLAN:END -->
