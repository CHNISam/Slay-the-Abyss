---
id: TASK-8
title: M1 回合制战斗核心（回合/能量/抽弃牌/伤害/格挡/敌人意图）
status: To Do
assignee: []
created_date: '2026-10-22 13:47'
due_date: '2026-10-24'
labels: []
milestone: m-2
dependencies:
  - TASK-7
priority: high
ordinal: 8000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
战斗主循环：抽牌、出牌、结算、弃牌、敌人按意图行动。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 回合流程正确：抽牌→出牌→结算→弃牌→敌人行动
- [ ] #2 能量每回合刷新，抽牌堆/弃牌堆循环正确
- [ ] #3 伤害与格挡结算正确（格挡回合结束清空）
- [ ] #4 敌人意图可见，且下回合行为与意图一致
<!-- AC:END -->
