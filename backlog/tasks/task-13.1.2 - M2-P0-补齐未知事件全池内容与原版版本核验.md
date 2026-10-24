---
id: TASK-13.1.2
title: 补齐第一幕全部可达事件
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-23 16:11'
updated_date: '2026-10-24 20:35'
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
按用户批准，补齐原版PC A0第一幕25个潜在事件及所有选项、代价和结果，保留原版出现条件与随机规则。既有七事件只是实现基线，不能作为最终受限池；详细来源与实现记录见附件。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 完整第一幕25事件的所有选项、代价和结果都做好；缺失项明确报缺，不作为最终删池理由。
- [ ] #2 出现条件、事件池顺序和随机消费有固定来源及独立回归，保持原版概率。
- [ ] #3 每个合法事件都能经正式入口遇到并完成，空牌组、资格不满足和重复输入均按原版处理。
- [ ] #4 已合并的配对和转化候选接入正式事件池、原生界面及永久奖励事务，并完成平台验收。
- [ ] #5 完整覆盖第一幕25个潜在事件（11普通、6祭坛、8条件一次性事件）；不能删池后重新分配概率。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 固定原版25事件资格、池顺序、随机消费和内容依赖。2. 逐项实现缺失18事件并接既有配对/转化。3. 统一接完整池、原生界面及永久移除/获得钩子，缺实现项明确报缺。4. 来源向量、真实交互、失败原子性和同源候选平台逐项验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
M3末张移除切片：固定CardGroup/Cleric/PurificationShrine/GoldenWing方法核对后，去除项目自加的至少两张限制，空牌组能正常开战、抽牌和失败。事件/商店原生控件37组与核心8组红绿及相关71组回归通过；金翼空组献祭仍扣7生命并完成，避免死选牌器。配对/转化仍不进入首发七事件池。来源blob、精确输入及原生空列表降级见docs/reviews/TASK-13.1.2-empty-permanent-deck.md。未编译/写副本/官方导入/实机，整体AC保持未勾。

2026-10-25 用户已批准完整25事件，纠正旧restricted-seven首页。Living Wall显式入口及Forget/Change/Grow已实现：42组定向通过，完整72槽34当前内容可用/38原子守卫；未接正常概率池，完整牌池/无色/诅咒与onRemove/onObtain/Searing Blow钩子仍须父线齐备。来源及边界 docs/reviews/TASK-13.1.2-living-wall.md。未知事件原220seed夹具30秒超时保留，正在原覆盖原预算优化；未宣称平台/完整事件池Done。
<!-- SECTION:NOTES:END -->
