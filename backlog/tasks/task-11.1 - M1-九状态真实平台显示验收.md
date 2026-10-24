---
id: TASK-11.1
title: 实测九种状态显示是否正确
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 22:20'
updated_date: '2026-10-24 03:48'
due_date: '2026-10-24'
labels: []
milestone: m-2
dependencies:
  - TASK-11
  - TASK-3.2
references:
  - docs/backlog-details/TASK-11.1.md
parent_task_id: TASK-11
ordinal: 33000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
到游戏里逐个检查九种状态的名字、层数、叠加和消退，确认玩家看到的与实际效果一致。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 在同一个测试版本检查九种状态的名字、层数和增减变化，保存截图与记录。
- [ ] #2 界面只显示真实状态，不偷偷改变战斗结果；版本和没通过的地方记清楚。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 固定本轮正常测试副本并核对源码。2. 自动订阅本轮日志，正常战斗领奖回图。3. 单独标注九状态验收夹具，记录双方名称、层数、叠加和触发衰减的画面。4. 保留源码版本、副本校验值、存档编号和逐项结果。
<!-- SECTION:PLAN:END -->
