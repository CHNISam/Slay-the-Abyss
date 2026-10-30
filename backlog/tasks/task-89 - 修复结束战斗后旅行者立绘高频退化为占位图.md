---
id: TASK-89
title: 修复结束战斗后旅行者立绘高频退化为占位图
status: To Do
assignee:
  - '@Furinya'
created_date: '2026-10-30 21:58'
updated_date: '2026-10-30 21:58'
labels:
  - playtest-20261030
  - p0
  - gpt
milestone: m-5
dependencies: []
references:
  - docs/backlog-details/PLAYTEST-20261030.md
  - docs/backlog-details/MOBILE-QA-20261029.md
parent_task_id: TASK-25
priority: medium
type: bug
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Owner实机反馈：点击结束战斗后，原本正常显示的旅行者立绘以报告约90%以上、接近必现的频率变成黄色几何占位图；个别进入战斗时也出现占位。此为用户报告，当前候选SHA与技术根因待独立核查；不要把预加载/回收假设当结论。GROK仅协作可见结果。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 正确呈现岩系旅行者自制战斗形象；在战斗结束及紧接的状态/场景切换中不退化为黄色占位图。
- [ ] #2 保留用户所述触发路径及当前候选/设备复测证据，明确独立复现率和实际原因；非当前候选测试不得冒充验证。
<!-- AC:END -->
