---
id: TASK-11.1
title: M1 九状态真实平台显示验收
status: To Do
assignee: []
created_date: '2026-10-22 22:20'
updated_date: '2026-10-23 14:14'
labels: []
milestone: m-2
dependencies:
  - TASK-11
  - TASK-3.2
parent_task_id: TASK-11
ordinal: 33000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
从TASK-11规则框架分离真实屏幕验收；九状态规则已合入，不用控件替身冒充游戏显示。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 在导入的同一战斗候选中核对九种状态名称/层数/叠加与衰减显示，保留截图和日志
- [ ] #2 状态UI仅只读核心，不改变结算；记录候选SHA、存档副本和未通过项
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-23独立九状态离线审计固定15f62a6：18组双方文本/叠层/衰减只读检查及真实endTurn三状态2→3→2通过；既有35+12+17+47组通过。仅测试准备，未开游戏，AC仍未勾。详见.artifacts/m1-audit/status/STATUS-ACCEPTANCE.md。
<!-- SECTION:NOTES:END -->
