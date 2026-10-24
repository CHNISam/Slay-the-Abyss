---
id: TASK-36.1
title: 翻页或关弹窗后，不要误买东西
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-23 14:26'
updated_date: '2026-10-24 03:15'
due_date: '2026-10-28'
labels: []
milestone: m-5
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/103'
  - docs/backlog-details/TASK-36.1.md
parent_task_id: TASK-36
priority: high
type: bug
ordinal: 48000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按住商店里的卡牌后翻页、打开牌库或切换页面，再松手不应该买到当前卡牌。选牌页面也一样。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 翻页、遮挡、切页面或重开后，之前那次按住不会误购买或误选，金币和卡组不变。
- [ ] #2 新的正常点击仍然可用，选牌和宝箱操作不受影响。
- [ ] #3 先复现再确认修好，自动检查通过；实际手机操作没测过就写明。
<!-- AC:END -->
