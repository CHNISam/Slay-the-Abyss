---
id: TASK-3
title: M1 战斗系统三层验证（编译/导入/真机试玩）
status: To Do
assignee: []
created_date: '2026-10-22 13:32'
updated_date: '2026-10-22 13:48'
due_date: '2026-10-24'
labels: []
milestone: m-2
dependencies:
  - TASK-8
  - TASK-9
  - TASK-10
  - TASK-11
priority: high
ordinal: 3000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
对已完成的战斗系统做三层分离验证：编译通过、写进存档、游戏里真的能打。三件事分开报告，不得互相冒充。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 write_graphs 编译通过并写进存档副本
- [ ] #2 存档副本导入成功，编辑器可打开
- [ ] #3 playtest 真机跑通一场完整战斗（出牌/结算/敌人行动），日志与截图符合预期
<!-- AC:END -->
