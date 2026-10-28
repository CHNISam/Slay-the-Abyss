---
id: TASK-56.1
title: 补齐猎人的倍毒、随机上毒和持续上毒
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-25 06:11'
updated_date: '2026-10-27 15:04'
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
parent_task_id: TASK-56
priority: medium
type: feature
ordinal: 97000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
本地机制实现切片已完成，前3项来源与真实Combat回归已有证明。原AC4的自然构筑及完整交互验收已逐字移交TASK-47并保持待验；完整职业卡池和正式平台仍由父任务与47负责。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 催化剂及升级版在动作执行时读取现有毒量，人工制品正确阻止新增毒，无毒目标不误耗人工制品。
- [x] #2 弹跳药瓶每次独立上毒并使用职业卡牌随机流，单一目标仍消耗随机数，保持下一目标预抽样的顺序。
- [x] #3 毒雾打出当回合不立即触发，从下个玩家回合抽牌后开始逐敌施毒，禁止抽牌不阻止该能力。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
固定源已核；在独立树实现倍毒、弹跳药瓶预抽样与毒雾抽牌后钩子。主线程负责共享入口；当前已验证版本冻结在sts-integration，全量检查期间只在独立下一阶段树开发，不提交推送。

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
