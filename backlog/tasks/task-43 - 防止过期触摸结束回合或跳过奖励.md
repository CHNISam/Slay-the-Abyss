---
id: TASK-43
title: 防止过期触摸结束回合或跳过奖励
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-23 12:57'
updated_date: '2026-10-23 13:07'
labels: []
milestone: m-2
dependencies: []
references:
  - src/lua/abyss_battle_ui.lua
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/110'
priority: high
type: bug
ordinal: 52000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
战斗操作按钮未保存按下时的上下文。旧触点经过牌库或另一手势结束回合后松开，可能再结束下一回合或跳过当前奖励。仅修BattleUI四类操作绑定，不改GameUI重开、战斗规则或数值。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 结束回合、跳过奖励及独立BattleUI开始/继续按钮的旧手势在上下文变化或取消后失效，不重复执行新状态动作。
- [ ] #2 合法新手势、无指针Click宿主、无坐标/无touchId输入、已有卡牌及药水操作保持可用。
- [ ] #3 配对触点真实命令回归先红后绿，经独立评审及当前SHA CI；平台派发实测单独保留。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 复现真实宿主旧按下跨牌库/换回合后的误执行。2. 给四类动作保存独立单次输入上下文，取消不复活，保留Click降级。3. 验证卡牌/药水兼容与真实命令正负例，独立评审并按PR/CI集成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
主审计真实配对输入8过5败，独立BattleUI2过2败。新增30组按8+8+8+6拆分，精确基线13过17败，候选全部通过；独立56组基线13过43败、候选56全过。现有79个Native Lua脚本全部通过；初次6个缺失快照工具输入补齐精确blob后重跑，不作为代码失败。两条旧卡牌用例仅改为完整Down/Up/Click，所有原断言保留，改后在基线仍11/11通过。只改四类BattleUI绑定，保留卡牌/药水tokens及混合Click-only宿主；不改GameUI重开、规则或数值。未运行被拒绝的本地npm全量检查/安装；正式Fengari与平台派发待验。
<!-- SECTION:NOTES:END -->
