---
id: TASK-4.15
title: 修复药水说明截断与不同药水图标混用
status: To Do
assignee:
  - '@Furinya'
created_date: '2026-10-30 21:58'
updated_date: '2026-10-30 21:58'
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
Owner截图：肌肉药水描述末尾在「人工」附近截断；两种不同药水在顶部槽位几乎相同图标，容易误用；开局另有HP显示成80/8的裁剪疑点。须区分素材区分度、源字符串、文本布局和实际状态，无需提前规定实现步骤。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 肌肉药水及其余长描述均完整显示，文本真实含义和使用/丢弃控件不被裁剪。
- [ ] #2 不同药水可通过正确的图形/语义可靠区分，保持原有效果和点击确认规则。
- [ ] #3 顶部生命等数值完整显示；裁剪问题与真实数值异常作出区分。
<!-- AC:END -->
