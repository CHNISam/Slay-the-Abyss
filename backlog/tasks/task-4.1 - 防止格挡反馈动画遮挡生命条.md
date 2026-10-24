---
id: TASK-4.1
title: 格挡动画不能挡住血条
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-23 14:56'
updated_date: '2026-10-24 03:15'
due_date: '2026-10-24'
labels: []
milestone: m-2
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/117#issuecomment-6367383439'
  - docs/backlog-details/TASK-4.1.md
parent_task_id: TASK-4
priority: medium
type: bug
ordinal: 49000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
获得格挡时的动画会变大，修好它压住血条的问题，让玩家始终看得清血量。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 玩家、普通敌人和Boss的格挡动画全过程都不挡血条，格挡数值正确。
- [ ] #2 其他动画保持正常，取消或播放结束后界面恢复正常。
- [ ] #3 先复现再确认修好，自动检查通过；游戏里看过才算实际视觉通过。
<!-- AC:END -->
