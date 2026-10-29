---
id: TASK-84
title: 让规划检查符合两职业比赛范围
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-28 14:40'
updated_date: '2026-10-29 01:55'
labels: []
dependencies: []
priority: medium
type: chore
ordinal: 125000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
现有规划检查硬编码四职业，导致正确的两职业M3范围无法通过；作为工程任务处理，不改变比赛验收标准。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 检查识别两职业两幕M3并拒绝过期的四职业必做范围。
- [x] #2 相关回归测试和Backlog一致性检查通过。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
把规划门禁改为最新两职业两幕范围，拒旧四职业必做标题；正反例与真实Backlog检查通过后收口。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
注意：PR #301 与 #302 有在途 TASK-79 重号；合入前必须通过CLI安全协调编号，避免覆盖。

合入最新主线后经Backlog doctor将本任务从79改为80；主线TASK-79仍为CI修复历史。

2026-10-29合流经原生doctor从TASK-80改为TASK-84，保留原Done的两职业门禁交付历史；当前用户范围已改旅行者单角两幕，相关门禁本轮同步。上游TASK-80是节点界面拆分，不应混用。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
规划检查已识别两职业两幕并拒绝旧四职业范围；27项正反例和真实Backlog检查通过。仅完成本地工程门禁，不代表比赛内容或实机通过。
<!-- SECTION:FINAL_SUMMARY:END -->
