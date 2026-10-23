---
id: TASK-15.6
title: 修正中型尖刺敌人的招式与污染牌
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-23 21:38'
labels: []
dependencies: []
parent_task_id: TASK-15
priority: high
type: bug
ordinal: 65000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按固定来源修复Spike Slime M的28–32血量、攻击8并加入一张污染状态牌、脆弱招式及30/70选择/三连限制；补齐状态牌花费1并消耗的真实行为。只处理该已有敌人与必要状态牌，不增加分裂机制或新平衡。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 固定来源明确敌人数据、选择限制与Slimed状态牌费用/消耗/不可升级规则
- [ ] #2 真实Combat/Run先失败再通过，覆盖抽到与打出状态牌、合法牌池排除、攻击后污染顺序及反伤死亡/末敌队列
- [ ] #3 数据与完整相关回归、独立评审及当前SHA正式CI通过，完整随机流/其它敌人/平台未验边界保留
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
核对源身份与队列；建立真实负例；最小敌人AI及状态牌执行修复；独立评审与正式CI后集成。
<!-- SECTION:PLAN:END -->
