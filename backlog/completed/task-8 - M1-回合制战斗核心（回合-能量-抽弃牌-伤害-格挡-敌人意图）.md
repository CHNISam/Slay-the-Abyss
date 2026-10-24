---
id: TASK-8
title: M1 回合制战斗核心（回合/能量/抽弃牌/伤害/格挡/敌人意图）
status: Done
assignee: []
created_date: '2026-10-22 13:47'
updated_date: '2026-10-22 15:13'
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
- [x] #1 回合流程正确：抽牌→出牌→结算→弃牌→敌人行动
- [x] #2 能量每回合刷新，抽牌堆/弃牌堆循环正确
- [x] #3 伤害与格挡结算正确（格挡回合结束清空）
- [x] #4 敌人意图可见，且下回合行为与意图一致
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 直接实现可require的Lua5.3纯战斗模块，JSON数据构建为Lua表；UI/平台无依赖。2. 同步测试抽弃循环、能量与非法操作原子性、伤害/格挡、意图、随机种子和胜败中止。3. 独立审查后PR集成，平台三层验证留TASK3，不虚假验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CLAIM 2026-10-22 主Agent /root；分支feat/task-8-combat-core；worktree .worktrees/combat-core；负责人Furinya掌握。TASK7已Done并经PR2集成481b926。文件边界src/lua/abyss_combat.lua和tests/lua/combat.lua。格挡按已审查data契约保留至拥有者下回合开始，避免玩家防御在敌方攻击前清空；任务原括注存在歧义，以实际行为测试证明。

实现纯Lua53战斗核心与15项真实源码测试；主Agent独立通过runner复跑15通过，官方MCP所带luaparse按Lua53语法检查通过。仅starter与基础op启用，未支持的高级效果在扣能量前拒绝，留TASK9/11扩展，不宣称37卡已全部实现。胜败、抽弃循环、能量、格挡、意图与无效命令原子性均有验证。未游戏运行。

独立TASK8.2复审通过，修复并回归满手overflow重抽及catalog跨战斗共享。意图AC验证为公开只读API与敌人实际执行一致；屏幕显示由TASK10独立验收，不声称本任务完成游戏UI。格挡保留至自己下回合开始并有吸收敌方攻击测试。主Agent及独立Agent完整复验53JS+15Lua；Python10通过1本机权限skip；PR7远端CI run39802353979通过。未平台导入或游戏运行。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
纯Lua53基础战斗循环与确定随机、牌堆、能量、伤害/格挡、只读意图、胜败中止完成，经独立审查、真实源码正负例及CI。20张基础op牌可接受，17张高级牌明确拒绝待TASK16；实际界面及三层游戏验证见TASK10/TASK3。
<!-- SECTION:FINAL_SUMMARY:END -->
