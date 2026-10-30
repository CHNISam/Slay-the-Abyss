---
id: TASK-38.2
title: 消除结束回合与弃牌堆在手机上的误触风险
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-30 21:58'
updated_date: '2026-10-30 22:30'
labels:
  - playtest-20261030
  - p0
  - grok
milestone: m-5
dependencies: []
references:
  - docs/backlog-details/PLAYTEST-20261030.md
  - docs/backlog-details/MOBILE-QA-20261029.md
parent_task_id: TASK-38
priority: medium
type: bug
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Owner截图右下方结束回合按钮与弃牌堆图标过近，触屏查看弃牌堆时可能误碰结束回合。Owner认可当前结束回合按钮造型，问题是交互安全而非要重新发明按钮外观。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 查看弃牌堆和结束回合两个触控目标可可靠区分，不易误触不可逆结束操作。
- [ ] #2 保留按钮既定外观及战斗规则，提供手机场景的实际点击/触控验收证据。
<!-- AC:END -->
