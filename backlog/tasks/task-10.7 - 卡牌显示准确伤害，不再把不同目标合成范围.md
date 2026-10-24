---
id: TASK-10.7
title: 卡牌显示准确伤害，不再把不同目标合成范围
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-24 04:23'
updated_date: '2026-10-24 04:24'
labels: []
milestone: m-2
dependencies: []
documentation:
  - docs/backlog-details/TASK-10.7.md
parent_task_id: TASK-10
priority: high
type: bug
ordinal: 81000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户实机发现普通攻击显示4～6点伤害。按原版区分未选目标与瞄准目标的确定数值，并检查整数资源。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 未指定目标和瞄准目标均显示原版对应的确定值，不合并成范围。
- [ ] #2 单体、多段、群攻、格挡、费用和意图核对通过；不改变结算和随机状态。
- [ ] #3 原问题先复现再通过，包含本轮实机复验和可核验的测试副本。
- [ ] #4 整数资源按整数显示，拒绝隐藏实际小数错误。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
先固定原版来源和复现，再修数值及同类显示，完整检查后合并；实机证据单独保留。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本地修复与回归已实施，完整检查进行中；新副本实机复验尚未完成，详见技术附件。
<!-- SECTION:NOTES:END -->
