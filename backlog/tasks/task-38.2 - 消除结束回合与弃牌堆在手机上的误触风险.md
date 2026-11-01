---
id: TASK-38.2
title: 消除结束回合与弃牌堆在手机上的误触风险
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-30 21:58'
updated_date: '2026-11-01 04:09'
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

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-11-01 R2：仅把抽弃牌计数改为依附图标的小圆徽标，冻结原热区和结束回合间距；Host及几何回归，手机AC保持未验。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-31：PR396@f5af0664已编码弃牌堆触控区上沿截断，与结束回合保留16单位间隔且不改按钮外观；离线断言通过，手机实际误触验收未完成，不勾验收。

2026-11-01 R2：计数视觉36圆、角位20/-14、字号20，旧56/40/24/-20专用于热区，实际84x82偏移±10/1及结束回合16间隔不变。Host0/1/9/10/99/100/999数据文本、两侧附着与三位宽度通过；设备误触保持未验。证据docs/evidence/hud-r2-20261101/README.md。
<!-- SECTION:NOTES:END -->
