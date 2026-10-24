---
id: TASK-12.4
title: 把第一幕地图规则对准原版
status: In Progress
assignee:
  - '@codex-map17'
created_date: '2026-10-23 01:56'
updated_date: '2026-10-24 03:10'
due_date: '2026-10-28'
labels:
  - required
  - rule-parity
milestone: m-4
dependencies:
  - TASK-12
references:
  - data/SOURCES.md
  - data/rules.json
  - src/lua/abyss_map.lua
  - docs/backlog-details/TASK-12.4.md
parent_task_id: TASK-12
priority: high
type: enhancement
ordinal: 40000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
核对第一幕地图怎么生成、哪里能走、会遇到什么敌人，按初代《杀戮尖塔》的规则修正。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 每条规则有可信的原版依据；不清楚的地方标出来，不猜。
- [ ] #2 确认15层地图、16层Boss、17层独立Boss宝箱，以及必出房间和路线连接规则。
- [ ] #3 敌人出现范围、重复限制和随机抽取方式符合原版，地图显示和保存也正确。
- [ ] #4 用多组测试检查路线、房间和出现概率；实际游戏里的结果另行确认。
<!-- AC:END -->
