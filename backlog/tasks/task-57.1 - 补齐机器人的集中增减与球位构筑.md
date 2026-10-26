---
id: TASK-57.1
title: 补齐机器人的集中增减与球位构筑
status: Done
assignee:
  - Furinya
created_date: '2026-10-25 06:11'
updated_date: '2026-10-26 13:00'
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
parent_task_id: TASK-57
priority: high
type: feature
ordinal: 98000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
本地机制实现切片已完成，前3项来源与真实Combat回归已有证明。原AC4的自然构筑及完整交互验收已逐字移交TASK-47并保持待验；完整职业卡池和正式平台仍由父任务与47负责。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 扩容与耗尽基本版和升级版正确，球位上限十；减少最后球位不唤起，零球位耗尽仍获得集中。
- [x] #2 首次集中、叠层、负集中、零层移除各自保持固定来源语义，球与玩家能力不出现两份互相矛盾的集中。
- [x] #3 人工制品按入站减益保护负集中和偏差；被挡后其他合法收益继续执行，多层偏差一次衰减只消耗一层人工制品。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
固定源已核；集中改为单一Power状态，处理人工制品、首次/叠层/归零、Bias与球位变化；独立模块和真实卡牌定向测试先行，主线程集成Actor/回合入口，不修改正在全量验证的版本。

本轮核对既有实现及实际回归，独立收口已合入机制；将自然获取/完整组合的原始验收完整交回47，不删除或降低标准。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-26在已合入e3a9fe2c对照原验收并复跑对应现有真实Combat回归，前3项已证明；本轮补齐勾选。第4项所需自然获取/组合或失败恢复的剩余证据继续保留，不Done。逐文件结果与边界见docs/BACKLOG-RECONCILE-20261026.md。

2026-10-26：对应poison/shivs/focus/mantra真实Combat回归上一轮已实际通过，本轮仍保留原范围。完整自然构筑与遗物交互原AC4完整交47未勾，不再把验收待办写成核心未实现。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
已交付的本地机制切片完成；来源与真实Combat基本/升级、顺序及边界回归已通过。原AC4完整移交47保持待验，父任务卡池及平台验收不随此关闭。
<!-- SECTION:FINAL_SUMMARY:END -->
