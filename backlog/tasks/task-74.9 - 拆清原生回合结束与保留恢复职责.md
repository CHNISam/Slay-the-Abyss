---
id: TASK-74.9
title: 拆清原生回合结束与保留恢复职责
status: Done
assignee:
  - Furinya
created_date: '2026-11-04 16:06'
updated_date: '2026-11-04 20:29'
labels: []
milestone: m-7
dependencies: []
documentation:
  - docs/backlog-details/TASK-74.9.md
parent_task_id: TASK-74
priority: medium
type: task
ordinal: 146000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
原生回合结束CC38，嵌套玩家清理CC37；非V4与V4清理时机不同，保留恢复与敌人行动快照需要独立合同。只治理现有职责，不合并实验协议。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 原生与V4清理时机、保留暂停恢复、敌人快照、RNG及异常旧新差分和真实错误变异通过
- [x] #2 入口与全部新职责受CC15约束，记录整体指标与依赖变化
- [x] #3 相关回归、独立复审、精确HEAD Full及合后验证分别通过
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 固定当前develop旧源，建立native/V4时序与保留/敌人快照差分。2. 同模块按玩家结束、保留恢复、敌人阶段职责治理，保留两次cleanup调用位置及resumingRetain捕获值；不改experimental。3. 全部新helper受CC15，真实变异和原回归、独审及Full通过再集成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本轮原生结束回合同模块职责已整理：入口CC38→12，旧内嵌cleanup37拆为10个helper最高11；范围总CC75→90如实披露。完整机械逆转后整个Combat源码与固定b4旧源逐字一致。独立VM13场景全图与3真实变异通过，主控组合16/16；owner_end/保留/战士/V4/Reptomancer等13份原Lua回归全过，工程5111/5111测量与15历史静态告警不变。详见docs/backlog-details/TASK-74.9.md与docs/evidence/native-turn-end-20261105.json。独审/精确HEAD Full/合后push仍待，AC不提前勾选。

精确7ae源码Full41883245183及独审通过；原生组合41895552479成功并squash到a308edbf。行为与复杂度/依赖两项有本轮证据；合后41900003124仍待，AC3与任务状态保留未完成。

PR513实际a308合后Full41900003124 attempt1成功，原验证器22932b37给出merged_passed。源码41883245183、失败队列41889284736、成功队列41895552479及全部成本分别保留；见docs/evidence/m7-runtime-delivery-20261105.json。父74/75、M7整体及官方/设备未验边界不变。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
原生结束CC38→12，保持V4后清理、保留暂停恢复、敌人引用快照与异常边界；精确交付通过。
<!-- SECTION:FINAL_SUMMARY:END -->
