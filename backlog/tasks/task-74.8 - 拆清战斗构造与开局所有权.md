---
id: TASK-74.8
title: 拆清战斗构造与开局所有权
status: Done
assignee:
  - Furinya
created_date: '2026-11-04 15:52'
updated_date: '2026-11-04 20:29'
labels: []
milestone: m-7
dependencies: []
documentation:
  - docs/backlog-details/TASK-74.8.md
parent_task_id: TASK-74
priority: medium
type: task
ordinal: 145000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Combat.new仍为CC82，集中选项、独立随机流、牌组实例、敌人和开局回调。按既有M7章程治理职责，保留两种协议与同局数据所有权。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 选项和随机流身份、prepared分支、牌组UID及开局回调边界旧新完整状态差分和真实错误变异通过
- [x] #2 入口和全部新helper接入CC15，公开全库复杂度与依赖变化
- [x] #3 原构造与开局回归、独立复审、精确HEAD Full及合后验证分别通过
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 固定完整旧源码，区分选项/随机流/牌组实例/敌人/开局职责与回调时机。2. 同模块机械提取，API、对象身份、顺序及异常保持；全部helper受CC15约束。3. 旧新独立VM、真实变异、原开局回归及独立精确组合审查后执行Full和合后验证。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
同模块构造职责完成，入口CC82→4/139→21，13helper最高12，含匿名回调全部受原CC15门禁。11场景完整图差分、8真实变异及原6入口通过。最终三模块组合44项通过，历史源码/出牌合同17项通过，工程5140测量完整；独立最终SHA、Full及合后验收仍待，不提前Done。

精确7ae源码Full41883245183及独审通过；原生组合41895552479成功并squash到a308edbf。行为与复杂度/依赖两项有本轮证据；合后41900003124仍待，AC3与任务状态保留未完成。

PR513实际a308合后Full41900003124 attempt1成功，原验证器22932b37给出merged_passed。源码41883245183、失败队列41889284736、成功队列41895552479及全部成本分别保留；见docs/evidence/m7-runtime-delivery-20261105.json。父74/75、M7整体及官方/设备未验边界不变。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
战斗构造CC82→4，保留选项/随机流身份、prepared、UID与回调顺序；完整图差分和精确交付通过。
<!-- SECTION:FINAL_SUMMARY:END -->
