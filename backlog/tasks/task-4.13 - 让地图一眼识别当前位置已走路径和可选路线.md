---
id: TASK-4.13
title: 让地图一眼识别当前位置已走路径和可选路线
status: To Do
assignee:
  - '@Furinya'
created_date: '2026-10-30 21:58'
updated_date: '2026-10-30 21:58'
labels:
  - playtest-20261030
  - p1
  - grok
milestone: m-5
dependencies: []
references:
  - docs/backlog-details/PLAYTEST-20261030.md
  - docs/backlog-details/MOBILE-QA-20261029.md
parent_task_id: TASK-4
priority: medium
type: enhancement
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Owner强调地图是**整体交互体验**问题：当前节点和连线灰暗、星星和金色路线不足以建立位置感；已走节点、当前位置、下一步可选节点难以区分。不得当作单一颜色/对比度调整，也不改变地图生成和规则。复用已 Done 的TASK-4.3滚动成果。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 地图静态可见时能清楚回答「我在哪、走过哪里、下一步能去哪」。
- [ ] #2 不同节点/线路状态、对比度和交互反馈整体协调，PC/手机实际屏幕上可辨。
- [ ] #3 不回退既有地图滚动、点击输入以及合法路径判定。
<!-- AC:END -->
