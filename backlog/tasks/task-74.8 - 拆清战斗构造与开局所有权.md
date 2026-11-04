---
id: TASK-74.8
title: 拆清战斗构造与开局所有权
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-04 15:52'
updated_date: '2026-11-04 16:04'
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
- [ ] #1 选项和随机流身份、prepared分支、牌组UID及开局回调边界旧新完整状态差分和真实错误变异通过
- [ ] #2 入口和全部新helper接入CC15，公开全库复杂度与依赖变化
- [ ] #3 原构造与开局回归、独立复审、精确HEAD Full及合后验证分别通过
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 固定完整旧源码，区分选项/随机流/牌组实例/敌人/开局职责与回调时机。2. 同模块机械提取，API、对象身份、顺序及异常保持；全部helper受CC15约束。3. 旧新独立VM、真实变异、原开局回归及独立精确组合审查后执行Full和合后验证。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
同模块构造职责完成，入口CC82→4/139→21，13helper最高12，含匿名回调全部受原CC15门禁。11场景完整图差分、8真实变异及原6入口通过。最终三模块组合44项通过，历史源码/出牌合同17项通过，工程5140测量完整；独立最终SHA、Full及合后验收仍待，不提前Done。
<!-- SECTION:NOTES:END -->
