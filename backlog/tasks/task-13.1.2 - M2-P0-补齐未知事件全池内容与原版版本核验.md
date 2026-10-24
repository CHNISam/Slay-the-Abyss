---
id: TASK-13.1.2
title: 把首发选定的事件做完整
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-23 16:11'
updated_date: '2026-10-24 10:24'
due_date: '2026-10-28'
labels:
  - p0
  - required
  - rule-parity
milestone: m-4
dependencies:
  - TASK-13.1.1
  - TASK-13.1.2.3
references:
  - docs/backlog-details/TASK-13.1.2.md
  - docs/DELIVERY-CLOSEOUT.md
parent_task_id: TASK-13.1
priority: high
ordinal: 54000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
先确定首发要放哪些事件，再把每个事件的选项和结果做齐。没做完的事件不能混进随机池。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 选定事件的所有选项、代价和结果都做好；未选定或未验证的事件不出现。
- [ ] #2 核对事件出现条件和随机规则，尤其容易出错的事件；没做的明确写出来。
- [ ] #3 每个选定事件都能正常遇到并完成；没有合适事件时给出清楚提示。
- [ ] #4 逐项决定已合并配对和转化候选是否进入首发，入选者接入正式事件池、界面和永久奖励事务并完成平台验收；不入选者在TASK-47清单明确排除，不能仅凭候选Done称可玩。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 按当前restricted-seven明确七事件和配对/转化排除范围。2. 复核固定CardGroup/GoldenWing来源，针对事件和商店末张移除、空牌组开战及恢复建立真实入口失败回归。3. 最小修正核心与UI命令条件，保持空组无卡可选的诊断和失败原子性。4. 跑定向及组合门禁，记录本地与平台未验边界，保持整体AC未勾。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
M3末张移除切片：固定CardGroup/Cleric/PurificationShrine/GoldenWing方法核对后，去除项目自加的至少两张限制，空牌组能正常开战、抽牌和失败。事件/商店原生控件37组与核心8组红绿及相关71组回归通过；金翼空组献祭仍扣7生命并完成，避免死选牌器。配对/转化仍不进入首发七事件池。来源blob、精确输入及原生空列表降级见docs/reviews/TASK-13.1.2-empty-permanent-deck.md。未编译/写副本/官方导入/实机，整体AC保持未勾。
<!-- SECTION:NOTES:END -->
