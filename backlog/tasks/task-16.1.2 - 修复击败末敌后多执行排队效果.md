---
id: TASK-16.1.2
title: 修复击败末敌后多执行排队效果
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-23 18:34'
labels: []
dependencies: []
parent_task_id: TASK-16.1
priority: high
type: bug
ordinal: 58000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
核对并修复最后敌人被击败后仍执行抽牌、能量等本应清除的排队效果，避免多余洗牌改变后续随机状态。仅按固定来源白名单处理已支持动作，不一律跳过所有后续效果，不修改数值或随机算法。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 固定来源核对末敌清队列时点与保留动作，区分仍有同伴和反伤死亡
- [ ] #2 真实出牌入口先失败再通过，验证牌堆、随机状态、能量、保留效果及异常回滚
- [ ] #3 独立评审与当前SHA正式CI通过，完整队列与平台未验边界明确保留
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
核对源动作顺序与白名单；建立负例；最小修复已支持动作清除并纠正旧错误预期；独立评审及正常PR集成。
<!-- SECTION:PLAN:END -->
