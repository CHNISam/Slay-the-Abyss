---
id: TASK-92
title: 核查出牌动作中剩余卡牌的红色禁用反馈
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-30 21:58'
updated_date: '2026-10-30 22:30'
labels:
  - playtest-20261030
  - p2
  - grok
dependencies: []
references:
  - docs/backlog-details/PLAYTEST-20261030.md
  - docs/backlog-details/MOBILE-QA-20261029.md
priority: low
type: enhancement
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**疑问，不是已确认Bug。** Owner实机截图：能量变成0/3的出牌瞬间，其余卡牌出现红色费用圈和「能量不足」横幅，感觉不舒适。不能将画面视为能量不足误判。参考原作出牌时序及既有用户试玩记录（MOBILE-QA-20261029 #1189）。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 明确核对原版及本作在规则禁用、演出期间暂时锁输入两者的显示差异与时序。
- [ ] #2 仅在确认体验确有改进空间时调整；维持费用规则、忙态禁止重复出牌和现有保护，不把调查当作已完成优化。
<!-- AC:END -->
