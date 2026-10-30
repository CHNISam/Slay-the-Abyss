---
id: TASK-4.14
title: 校正顶栏卡组遗物图标计数与空间层级
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-30 21:58'
updated_date: '2026-10-30 22:30'
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
type: bug
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Owner截图：卡组入口不是清楚的卡牌图标，两个类似箱子的遗物入口语义不明，顶栏右侧与计数相互挤压且残留一个「0」。同时关注不同图标表达完全不同语义的问题。圣遗物可核对原版顶栏下第二排布局，但不预设必须照某个像素实现。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 卡组、遗物及其数量一一对应，消除右侧残留「0」与任何遮挡。
- [ ] #2 图标能区分不同功能；遗物数量增多仍保持清晰，不挤压战斗核心信息。
- [ ] #3 对当前官方 UI 图标映射做必要核查，已发现的一图多义有明确判断，未证实的部分不冒充事实。
<!-- AC:END -->
