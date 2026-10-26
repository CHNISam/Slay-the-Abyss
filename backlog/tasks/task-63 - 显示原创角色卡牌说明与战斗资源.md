---
id: TASK-63
title: 显示原创角色卡牌说明与战斗资源
status: Done
assignee:
  - Furinya
created_date: '2026-10-26 05:23'
updated_date: '2026-10-26 08:26'
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
- [x] #1 全部DSL可显示；未知操作拒绝；实时资源包含治疗额度与剩余阶段
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
独立纯呈现模块与定向Lua回归，主代理接既有UI；不改变主题和数值。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
独立Executor codex-v4-display/sessionc8da9fe8，source a3335f0。3文件精确scope；Lua13组、600版文案遍历及固定Luacheck通过。独立lease已释放交统一集成，UI实机状态未提升。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
完整34操作/32条件文案与资源格式器接入现有UI；13组显示回归、600全文遍历和生成树查看回归通过；实机仍not_run。
<!-- SECTION:FINAL_SUMMARY:END -->
