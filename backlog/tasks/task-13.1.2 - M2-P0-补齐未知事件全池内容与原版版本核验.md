---
id: TASK-13.1.2
title: 把首发选定的事件做完整
status: To Do
assignee: []
created_date: '2026-10-23 16:11'
updated_date: '2026-10-24 03:10'
due_date: '2026-10-28'
labels:
  - p0
  - required
  - rule-parity
milestone: m-4
dependencies:
  - TASK-13.1.1
  - TASK-13.1.2.3
references:
  - docs/backlog-details/TASK-13.1.2.md
parent_task_id: TASK-13.1
priority: high
ordinal: 54000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
先确定首发要放哪些事件，再把每个事件的选项和结果做齐。没做完的事件不能混进随机池。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 选定事件的所有选项、代价和结果都做好；未选定或未验证的事件不出现。
- [ ] #2 核对事件出现条件和随机规则，尤其容易出错的事件；没做的明确写出来。
- [ ] #3 每个选定事件都能正常遇到并完成；没有合适事件时给出清楚提示。
<!-- AC:END -->
