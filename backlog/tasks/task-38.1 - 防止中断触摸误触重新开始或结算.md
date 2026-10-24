---
id: TASK-38.1
title: 取消退出后，不要误重开或误结算
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-23 15:55'
updated_date: '2026-10-24 03:15'
due_date: '2026-10-28'
labels: []
milestone: m-5
dependencies: []
references:
  - src/lua/abyss_game_ui.lua
  - docs/backlog-details/TASK-38.1.md
parent_task_id: TASK-38
priority: high
type: bug
ordinal: 50000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
修复旧触摸留在界面上的问题，避免取消退出后又意外点到重新开始或提交结算。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 开关弹窗、换页面、重开或缩放后，之前的触摸不会误重开或误提交结算。
- [ ] #2 别的触点和重复点击不会乱执行；正常的新点击仍然可用。
- [ ] #3 先复现再确认修好，结算只发生一次；自动检查和游戏实测分别记录。
<!-- AC:END -->
