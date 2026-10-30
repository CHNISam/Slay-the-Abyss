---
id: TASK-4.11
title: 修复退出本局警告被操作说明遮挡及提示层级
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-30 21:58'
updated_date: '2026-10-30 22:49'
labels:
  - playtest-20261030
  - p0
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
Owner截图：放弃本局确认框中的「操作说明」入口直接压住失去进度的正文；说明文字冗长，重要后果与创作者提示混杂。已在10/29报告出现，本次再次复现反馈。保留真正退出的确认操作，不改结算逻辑。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 退出本局的风险说明完整可读，「操作说明」及其它按钮不会遮挡正文。
- [ ] #2 取消与确认的含义清楚，操作不穿透；与本轮 #21 精确追加文案各自核对。
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-31：PR396@f5af0664已编码退出弹窗页眉/正文/辅助说明分层，定向布局断言覆盖互不遮挡；本轮GIL已构建读回，仍待同候选官方导入与手机实测，不勾验收。见PLAYTEST-20261030末节。
<!-- SECTION:NOTES:END -->
