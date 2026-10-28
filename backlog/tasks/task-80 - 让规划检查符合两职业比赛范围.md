---
id: TASK-80
title: 让规划检查符合两职业比赛范围
status: To Do
assignee:
  - '@Furinya'
created_date: '2026-10-28 14:40'
updated_date: '2026-10-28 15:21'
labels: []
dependencies: []
priority: low
type: chore
ordinal: 125000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
现有规划检查硬编码四职业，导致正确的两职业M3范围无法通过；作为工程任务处理，不改变比赛验收标准。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 检查识别两职业两幕M3并拒绝过期的四职业必做范围。
- [ ] #2 相关回归测试和Backlog一致性检查通过。
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
注意：PR #301 与 #302 有在途 TASK-79 重号；合入前必须通过CLI安全协调编号，避免覆盖。

合入最新主线后经Backlog doctor将本任务从79改为80；主线TASK-79仍为CI修复历史。
<!-- SECTION:NOTES:END -->
