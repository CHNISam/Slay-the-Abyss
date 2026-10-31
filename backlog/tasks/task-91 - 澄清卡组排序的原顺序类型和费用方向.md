---
id: TASK-91
title: 澄清卡组排序的原顺序类型和费用方向
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-30 21:58'
updated_date: '2026-10-31 15:04'
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
Owner截图：卡组页显示「排序·原顺序」但没有解释原顺序是获得次序还是本次未排序次序；费用/类型排序没有明确升降或稳定顺序。功能已实现，改进仅聚焦排序呈现和实际规则一致性，不扩大卡组系统范围。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 排序选项准确表达原始顺序含义与费用升降方向，用户可预测结果。
- [ ] #2 排序结果与所选规则一致，不破坏原有过滤、卡牌状态和手牌逻辑。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 核对原序与费用类型排序。2. 只澄清文案保留规则。3. 定向回归后交独立复审。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本轮排序标签和现有底部说明已完成，算法与过滤零改。定向浏览、布局、历史合同7/7通过；证据见 docs/backlog-details/TASK-91.md。无候选和设备实测，保持进行中，待独立复审和主控集成。
<!-- SECTION:NOTES:END -->
