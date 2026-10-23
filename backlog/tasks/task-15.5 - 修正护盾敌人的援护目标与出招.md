---
id: TASK-15.5
title: 修正护盾敌人的援护目标与出招
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-23 21:11'
labels: []
dependencies: []
parent_task_id: TASK-15
priority: high
type: bug
ordinal: 64000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按固定来源修复shield_gremlin的12–15血量、援护7目标选择和孤立后永久攻击6；并修正敌群回合开始格挡重置/毒结算先于行动的必要时序，避免援护给后行动同伴的格挡立即消失。只改已支持行为，不引入新平衡。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 固定来源明确援护目标过滤、单目标/空目标随机消费和孤立转攻击规则
- [ ] #2 真实Combat/Run先失败再通过，覆盖敌群格挡先重置、毒先结算、目标死亡及持久援护结果
- [ ] #3 界面意图准确说明援护对象，数据/既有回归及独立评审、当前SHA CI通过；平台与全随机流边界保留
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
核对源动作队列和所有权；建立真实负例；最小敌人行为及必要敌群前置时序修复；独立审查与正式CI后集成。
<!-- SECTION:PLAN:END -->
