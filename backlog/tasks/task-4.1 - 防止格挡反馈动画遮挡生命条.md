---
id: TASK-4.1
title: 格挡动画不能挡住血条
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-23 14:56'
updated_date: '2026-10-24 05:53'
due_date: '2026-10-24'
labels: []
milestone: m-2
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/117#issuecomment-6367383439'
  - docs/backlog-details/TASK-4.1.md
parent_task_id: TASK-4
priority: medium
type: bug
ordinal: 49000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
获得格挡时的动画会变大，修好它压住血条的问题，让玩家始终看得清血量。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 玩家、普通敌人和Boss的格挡动画全过程都不挡血条，格挡数值正确。
- [ ] #2 其他动画保持正常，取消或播放结束后界面恢复正常。
- [ ] #3 先复现再确认修好，自动检查通过；游戏里看过才算实际视觉通过。
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-24最新7e1123b独立复核：横向scale=1修正已由PR109合入95ce2bd，现有真实Defend/1至5敌人/Boss/取消回归全部保留。本轮Fengari battle_ui 52/52通过（19.021秒），布局主题12项通过；实际查看5165候选defend-two截图，玩家格挡5与74/80清晰，不能外推敌人/Boss全过程。未新增游戏操作，尚需同候选连续帧/录像确认玩家、普通敌人各列宽及Boss格挡动画，故AC1/3与整体继续保留。

2026-10-24准备同源统一诊断副本：1–5普通敌人及Guardian六种布局，108个格挡时间线样本、6次播放中取消，旧横向缩放负控失败且修复版离线通过。此为显式夹具/暂停时间线，不认证正常AI、节奏或通关。原生视觉仍缺；自动试玩前台切换失败，未勾AC。
<!-- SECTION:NOTES:END -->
