---
id: TASK-10.4
title: 修复奖励HUD回血与非目标牌敌人点击误触
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-22 17:08'
updated_date: '2026-10-22 17:11'
labels: []
dependencies: []
parent_task_id: TASK-10
type: bug
ordinal: 29000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
最新视觉整合重写遗漏奖励阶段HUD同步且敌人点击会误打出已选防御牌。基于f7d5d75隔离修复，保留审查者原失败探针，不改主题布局或外部工作树。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 真实胜利奖励HUD显示run回血后生命并归零战斗临时态，有永久真实Lua回归
- [x] #2 选中非目标牌后敌人点击只查看意图并保留选择，不花能量或移牌，攻击目标执行仍正常
- [x] #3 独立审查者原失败探针转绿，完整门禁通过且修改仅授权边界
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 在f7d5d75运行审查者冻结探针并保留红灯证据。2. 加永久真实UI回归，修render仅combat读battle临时态及enemy点击needsTarget门控。3. 原探针转绿+完整npmcheck，提交独立PR由content_review复审。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CLAIM quality-gates；worktree .worktrees/ui-regressions；branch feat/task-10-4-ui-regressions；精确基线f7d5d75；仅abyss_battle_ui.lua、tests/lua/battle_ui.lua及本task；不改theme/layout或外部battle-ui，不操作GUI。

红灯证据：f7d5d75原冻结hp probe run56/HUD50energy2 exit1；defend probe enemy点击energy3→2hand5→4 exit1；新增永久non-target回归修前exit1。最小修复：render仅combatphase使用battle，reward/map读取run持久态并清空energy/draw/discard等临时HUD；enemycallback仅selected且needsTarget执行，否则看意图并保留选择。原两probe未修改，修后均exit0（HP56energy0，energy3/hand5不变）。永久UI11项含两新增真实回归通过；完整npmcheck退出0，JS有6明确symlink权限skip、Python10pass1WinError1314skip，真实Lua UI11+core15+map10+run8+status26全部通过；syntax/data/UI/themebuild与gitdiffcheck通过。仅UI逻辑/该Lua测试/本task，不动theme/layout/外部树/GUI。保持InProgress待content_review独立复验及root集成，不宣称游戏可玩。
<!-- SECTION:NOTES:END -->
