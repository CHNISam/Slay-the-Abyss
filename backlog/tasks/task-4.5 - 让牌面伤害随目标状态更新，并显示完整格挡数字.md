---
id: TASK-4.5
title: 修复格挡数字裁切，并按原版核实伤害预览
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-24 12:17'
updated_date: '2026-10-24 13:30'
due_date: '2026-10-24'
labels: []
milestone: m-5
dependencies: []
references:
  - docs/reviews/USER-PLAYTEST-20261024.md
parent_task_id: TASK-4
priority: high
type: bug
ordinal: 86000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户实机发现格挡10只显示1，需要完整显示多位数字。伤害预览按核实后的原版语义验收：普通手牌包含玩家修正，瞄准敌人时加入目标易伤，取消或状态移除后恢复。具体证据和相邻排查见docs/reviews/USER-PLAYTEST-20261024.md。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 玩家及敌人的格挡1、10、99、100和999均完整可读，不遮住血条或相邻敌人。
- [ ] #2 保留能复现旧问题的自动回归，并以同源候选的实机截图确认两项修复。
- [ ] #3 普通手牌按玩家修正显示，瞄准具体敌人时才加入易伤；取消或状态移除后恢复原版数值。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
保留原版普通手牌/瞄准/取消区分，撤回尚未提交的整手牌目标修正试改。格挡按位数拓宽，窄敌列采用不挤压生命数字的排布；同根因状态层数和抽弃牌行高补统一门禁。保留旧版证红、定向回归与同候选实机证据。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
用户随后要求先核实原版。固定AbstractPlayer.renderHand 1678-1715证明calculateCardDamage目标后渲染，随后applyPowers还原；普通手牌不直接算敌方易伤是正确语义。补瞄准/取消/目标状态移除/玩家力量虚弱恢复回归15组通过。格挡旧版真实树证红hero clips Block10；首次拓宽又被相邻生命容量契约证红enemy1 clips HP while showing Block10，改窄列放入画像下角，保留完整生命带，55组UI含动画均绿。全项实机尚未复验，不勾AC。
<!-- SECTION:NOTES:END -->
