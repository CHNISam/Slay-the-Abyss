---
id: TASK-3.3.1
title: 取消退出后，松手不能误进地图节点
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-24 01:50'
updated_date: '2026-10-24 03:10'
due_date: '2026-10-26'
labels: []
milestone: m-3
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/150'
  - docs/backlog-details/TASK-3.3.1.md
parent_task_id: TASK-3.3
priority: high
type: bug
ordinal: 74000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
修复这个问题：在地图上按住，打开退出框再取消，松手时却误进了战斗。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 取消退出后，原来按住的那一下不会误进节点。
- [ ] #2 多点触摸和上局留下的点击不会串到当前操作；正常点击和拖动仍可用。
- [ ] #3 用实际游戏界面复现问题，并确认修复有效。
- [ ] #4 地图规则和外观不变；电脑与手机的测试结果分别记录。
<!-- AC:END -->
