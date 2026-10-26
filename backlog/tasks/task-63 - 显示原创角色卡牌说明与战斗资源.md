---
id: TASK-63
title: 显示原创角色卡牌说明与战斗资源
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-26 05:23'
updated_date: '2026-10-26 05:53'
due_date: '2026-10-28'
labels: []
milestone: m-4
dependencies: []
priority: high
type: feature
ordinal: 110000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
原创DSL需要在现有卡面与战斗界面清楚展示条件、资源与剩余次数。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 全部DSL可显示；未知操作拒绝；实时资源包含治疗额度与剩余阶段
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
独立纯呈现模块与定向Lua回归，主代理接既有UI；不改变主题和数值。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
独立Executor codex-v4-display/sessionc8da9fe8，source a3335f0。3文件精确scope；Lua13组、600版文案遍历及固定Luacheck通过。独立lease已释放交统一集成，UI实机状态未提升。
<!-- SECTION:NOTES:END -->
