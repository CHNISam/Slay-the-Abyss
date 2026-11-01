---
id: TASK-74.1
title: 复核未知意图和长提示的显示证据
status: To Do
assignee:
  - Furinya
created_date: '2026-10-28 14:45'
labels: []
dependencies: []
references:
  - docs/backlog-details/ENGINEERING-HEALTH-20261028.md
parent_task_id: TASK-74
priority: medium
type: task
ordinal: 123000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
工程审计发现UNKNOWN主图可能被详情推成buff，最长143字符提示在旧1080x32布局可能裁切。已有独立离线候选与完整恢复证据；后续以实际主线核对，不重新混合两套历史回放。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 未知召唤意图按原来源保持unknown，详情和实际目标行为不变
- [ ] #2 最长提示与拥挤敌人、药水及浮字显示完整并有实际证据
<!-- AC:END -->
