---
id: TASK-8
title: M1 回合制战斗核心（回合/能量/抽弃牌/伤害/格挡/敌人意图）
status: In Progress
assignee: []
created_date: '2026-10-22 13:47'
updated_date: '2026-10-22 14:33'
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

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 直接实现可require的Lua5.3纯战斗模块，JSON数据构建为Lua表；UI/平台无依赖。2. 同步测试抽弃循环、能量与非法操作原子性、伤害/格挡、意图、随机种子和胜败中止。3. 独立审查后PR集成，平台三层验证留TASK3，不虚假验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CLAIM 2026-10-22 主Agent /root；分支feat/task-8-combat-core；worktree .worktrees/combat-core；负责人Furinya掌握。TASK7已Done并经PR2集成481b926。文件边界src/lua/abyss_combat.lua和tests/lua/combat.lua。格挡按已审查data契约保留至拥有者下回合开始，避免玩家防御在敌方攻击前清空；任务原括注存在歧义，以实际行为测试证明。
<!-- SECTION:NOTES:END -->
