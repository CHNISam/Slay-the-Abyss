---
id: TASK-58.1
title: 做好观者的占卜选牌与后续出牌
status: Done
assignee:
  - Furinya
created_date: '2026-10-25 06:11'
updated_date: '2026-10-27 04:15'
labels:
  - required
  - sts1
  - builds
milestone: m-4
dependencies: []
references:
  - >-
    https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0
  - docs/BACKLOG-RECONCILE-20261026.md
  - docs/BACKLOG-AUDIT-20261026.md
  - docs/rules/WATCHER_FLOW_BUILD.md
parent_task_id: TASK-58
priority: medium
type: feature
ordinal: 99000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
占卜需要在出牌中途选择抽牌堆顶部的牌，不能复用只能位于牌末尾的弃牌接口。首批覆盖 Cut Through Fate、Third Eye、Just Lucky 和 Nirvana，再验证完整占卜构筑。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 只窥当前抽牌堆顶部规定数量，不足时不重洗；允许选零张，未选牌保持原相对顺序。
- [x] #2 Cut Through Fate 的后续抽牌、Just Lucky 的后续格挡和伤害都等待确认，不能提前执行或抽回尚未处置的使用牌。
- [x] #3 空抽牌堆、零数量和选零张仍按来源触发占卜能力；Nirvana 追加格挡位于原生剩余动作及使用牌处置之后。
- [x] #4 选择不冒充手动弃牌，不触发战术大师或本能；Golden Eye 与 Weave 等未完成交互明确列出。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
按固定源实现占卜候选、选零、顺序和Nirvana尾动作，依赖数据化可暂停队列。仅在下一阶段实验树接入，不提前标记可用或完成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-26在已合入e3a9fe2c对照原验收并复跑对应现有真实Combat回归，前3项已证明；本轮补齐勾选。第4项所需自然获取/组合或失败恢复的剩余证据继续保留，不Done。逐文件结果与边界见docs/BACKLOG-RECONCILE-20261026.md。

2026-10-26复核：18组watcher_scry本轮通过，含不触发手动弃牌、失败恢复及死亡顺序；Weave召回早已由Watcher Flow接入，旧未实现备注失效，来源及真实双阶段/幂等回归见WATCHER_FLOW_BUILD。Golden Eye完整遗物交互仍归14.1/47，不冒充全池或原生实机。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
占卜本地机制切片完成，18组真实Combat顺序/事务回归通过；Weave已接，Golden Eye及平台责任明确留14.1/47。
<!-- SECTION:FINAL_SUMMARY:END -->
