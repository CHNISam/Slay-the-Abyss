---
id: TASK-30
title: 拖牌到场上，松手就出牌
status: To Do
assignee: []
created_date: '2026-10-23 00:59'
updated_date: '2026-10-24 03:10'
due_date: '2026-10-28'
labels:
  - ui
  - combat
  - interaction
milestone: m-5
dependencies:
  - TASK-10
references:
  - docs/design/UI_DESIGN.md
  - docs/design/prototype/index.html
  - docs/backlog-details/TASK-30.md
priority: high
type: enhancement
ordinal: 36000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
防御等不需要选敌人的牌，拖出手牌区后松手就能打出，不用再点一次。需要选敌人的牌仍要拖到目标上。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 不需要选敌人的牌，拖到战场空地松手就出，不用第二次点击。
- [ ] #2 能看清哪里可以出牌；松在手牌区或无效位置会取消，不误点其他按钮。
- [ ] #3 需要目标的牌拖到合法敌人才能出，松在空地不能替玩家随便选敌人。
- [ ] #4 一次拖动只出一次；费用不足或当前不能出牌时，不扣费用也不丢牌。
- [ ] #5 电脑鼠标和手机触摸都测过，并保留点选出牌的备用方式。
- [ ] #6 记录游戏里的实际操作结果；做不到的说明原因，不能把点选可用当成拖牌已完成。
<!-- AC:END -->
