---
id: TASK-25.3
title: 首发卡牌框与图标制作（实机门槛后）
status: To Do
assignee:
  - '@art-card'
created_date: '2026-10-22 16:43'
labels:
  - art
  - launch
dependencies:
  - TASK-10.1
references:
  - docs/art/PIPELINE.md
parent_task_id: TASK-25
type: task
ordinal: 29000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
复用PR27的单卡排版和现有岩荧设计，为首发实际卡池提供美术。当前仅有离线和存档副本静态校验，实机门槛未过，不得开始批产。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 只采用TASK-10.1已实机通过的卡框和原生文字流程；记录尺寸、控件预算、模板绑定和对照截图
- [ ] #2 按data/cards.json及已批准表现清单交付首轮卡框、卡背、图标；不改核心玩法或重复实现TASK-10控制器
- [ ] #3 独立feat分支与PR；离线检查和平台导入/真机证据分开；主Agent审查后集成
<!-- AC:END -->
