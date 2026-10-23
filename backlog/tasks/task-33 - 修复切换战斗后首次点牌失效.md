---
id: TASK-33
title: 修复切换战斗后首次点牌失效
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-23 07:25'
updated_date: '2026-10-23 07:28'
labels: []
milestone: m-2
dependencies: []
references:
  - src/lua/abyss_battle_ui.lua
  - tests/lua/game_ui.lua
priority: medium
type: bug
ordinal: 45000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
上一场选择第二名敌人后，同局进入单敌战斗，旧目标编号导致首次点攻击牌被拒绝；第二次操作会恢复，并非卡死。仅修复本地控制器选择状态，实机完整流程仍由TASK-3验收。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 进入新战斗后首次点攻击牌即可正常选择并对有效敌人出牌
- [ ] #2 同一场战斗刷新保留有效目标和已选牌，既有动画及过期输入保护不回退
- [ ] #3 真实GameUI回归覆盖红转绿，独立审查及当前提交CI通过
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Executor=dot。按已确认的run.combat身份变化清理旧选择，仅改战斗UI与真实控件回归；独立评审后走PR/CI。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
基线91f50d1真实GameUI回归复现首次点牌被旧目标拒绝。最小修复按已提交combat身份重置目标和选牌；补同场刷新、实际动画帧和同UID战斗替换保护。系统Lua52套件通过（GameUI21、BattleUI43），独立审查与负例验证；正式当前SHA CI及合并待完成，未作平台实机验收。
<!-- SECTION:NOTES:END -->
