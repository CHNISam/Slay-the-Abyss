---
id: TASK-15.2
title: 补齐仪式敌人的意图随机消耗
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-23 19:26'
labels: []
dependencies: []
parent_task_id: TASK-15
priority: high
type: bug
ordinal: 60000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
核对Cultist开场和行动后RollMove的随机消耗，修复固定意图分支漏抽。保留仪式生效时点、攻击数值和现有死亡清队列规则，不改随机算法或其他敌人。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 固定来源区分初始化、行动后与反伤死亡后仍有同伴时的RollMove规则
- [ ] #2 真实Combat负例先失败再通过，验证调用顺序、行动次数、末敌/同伴死亡与仪式行为
- [ ] #3 数据及生成回归、独立评审与当前SHA CI通过，完整随机流和平台验收边界保留
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
源码核对；真实入口负例；最小数据/AI修复；独立评审及正式CI后正常集成。
<!-- SECTION:PLAN:END -->
