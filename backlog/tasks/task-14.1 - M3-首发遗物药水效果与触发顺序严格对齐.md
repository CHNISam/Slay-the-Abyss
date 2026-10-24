---
id: TASK-14.1
title: 核对遗物和药水的实际效果
status: In Progress
assignee:
  - '@Codex-relic-order'
created_date: '2026-10-23 01:57'
updated_date: '2026-10-24 03:10'
due_date: '2026-10-28'
labels:
  - required
  - rule-parity
milestone: m-4
dependencies:
  - TASK-14
references:
  - data/SOURCES.md
  - data/relics.json
  - data/potions.json
  - docs/backlog-details/TASK-14.1.md
parent_task_id: TASK-14
priority: high
type: enhancement
ordinal: 42000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
逐件检查首发遗物和药水：数值是否正确、什么时候触发、用了以后是否真正生效。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 每件道具的效果都有原版依据，没查清的不能当成已通过。
- [ ] #2 数值、对象、持续时间、使用限制和触发顺序符合原版。
- [ ] #3 从正常背包使用和触发，检查叠加、跨房间、战斗胜利和重复使用等情况。
- [ ] #4 保存测试和实际游戏记录，明确哪些只在本地测过、哪些已在游戏里验证。
<!-- AC:END -->
