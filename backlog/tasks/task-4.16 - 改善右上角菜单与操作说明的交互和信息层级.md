---
id: TASK-4.16
title: 改善右上角菜单与操作说明的交互和信息层级
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
type: enhancement
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Owner反馈：菜单只能点「继续游戏」关闭；未启程时仍显示不可进入的「查看地图（启程后可用）」；操作说明六宫格信息堆砌，新手看不懂；血量、金币等资源标识缺少快速解释。应整体梳理信息架构和触屏交互，不强行指定控件结构。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 菜单可通过非破坏性的直观操作关闭，不误触后台游戏/放弃本局。
- [ ] #2 未启程地图入口不误导玩家；已可用时正常进入。
- [ ] #3 操作说明层次清楚、能快速找到出牌/取消/详情/药水/地图等信息；基础资源含义易获知。
<!-- AC:END -->
