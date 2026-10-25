---
id: TASK-58.1
title: 做好观者的占卜选牌与后续出牌
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-25 06:11'
updated_date: '2026-10-25 08:18'
labels:
  - required
  - sts1
  - builds
milestone: m-4
dependencies: []
references:
  - >-
    https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0
parent_task_id: TASK-58
priority: high
type: feature
ordinal: 99000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
占卜需要在出牌中途选择抽牌堆顶部的牌，不能复用只能位于牌末尾的弃牌接口。首批覆盖 Cut Through Fate、Third Eye、Just Lucky 和 Nirvana，再验证完整占卜构筑。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 只窥当前抽牌堆顶部规定数量，不足时不重洗；允许选零张，未选牌保持原相对顺序。
- [ ] #2 Cut Through Fate 的后续抽牌、Just Lucky 的后续格挡和伤害都等待确认，不能提前执行或抽回尚未处置的使用牌。
- [ ] #3 空抽牌堆、零数量和选零张仍按来源触发占卜能力；Nirvana 追加格挡位于原生剩余动作及使用牌处置之后。
- [ ] #4 选择不冒充手动弃牌，不触发战术大师或本能；Golden Eye 与 Weave 等未完成交互明确列出。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
按固定源实现占卜候选、选零、顺序和Nirvana尾动作，依赖数据化可暂停队列。仅在下一阶段实验树接入，不提前标记可用或完成。
<!-- SECTION:PLAN:END -->
