---
id: TASK-29
title: 让出牌、受击和敌人行动都有反馈
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 23:29'
updated_date: '2026-10-27 04:15'
due_date: '2026-10-28'
labels:
  - P1
  - battle-feedback
  - awaiting-live
milestone: m-5
dependencies:
  - TASK-10
  - TASK-11
references:
  - docs/COMBAT_FEEDBACK.md
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/52'
  - docs/backlog-details/TASK-29.md
  - docs/DELIVERY-CLOSEOUT.md
  - docs/BACKLOG-AUDIT-20261026.md
priority: medium
type: enhancement
ordinal: 38000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
把出牌、打中、掉血、格挡和敌人行动按正确顺序演出来，让玩家看得懂发生了什么。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 出牌会接上攻击、命中、伤害数字和血条变化，状态与死亡也有对应表现。
- [x] #2 敌人按行动顺序演出，多段攻击、多个敌人、群攻、中毒和反伤不会漏掉。
- [x] #3 自动测试确认不改玩法和随机结果，不重复播放，演出出错后还能继续操作。
- [ ] #4 在同一个游戏版本实测画面和声音，保存截图或录像，没听验的音效写明。
- [ ] #5 本任务负责人收集TASK-29.1及4.1同版本原生演出和音效证据，交TASK-4审阅，独立音效存档试听不能替代正式游戏混音。
<!-- AC:END -->
