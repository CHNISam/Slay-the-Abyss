---
id: TASK-99
title: 修复重跑继承作业的交付收据识别
status: Done
assignee:
  - Furinya
created_date: '2026-11-04 04:57'
updated_date: '2026-11-04 08:38'
labels: []
milestone: m-7
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/501'
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/502#issuecomment-6622281783'
documentation:
  - docs/backlog-details/TASK-99.md
priority: medium
type: bug
ordinal: 141000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
PR #501 合后仅重跑失败作业时，GitHub 将保留的成功首分片复制到新 attempt，实际 checkout 收据仍属原执行。合入 #502 后 collector 和 Full 发布器都按最新记录 attempt 拒绝原收据。本任务只修严格继承识别，不接管 TASK-98 的规则设置、其他 PR 或发布。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 PR、push 与 Full 发布器只接受可证明的原执行收据，不改写 GitHub 原始作业或收据身份
- [x] #2 缺失或歧义历史、最新失败、真实重跑、错误 run/head/SHA/父提交及 artifact 均保持拒绝
- [x] #3 定向正反测试和独立复审通过，精确 HEAD 完整 CI 与合后 squash/push 验证分别记录
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 在 develop 67493f1 上复用已独立复审的严格继承解析；collector 与 Full 发布器共享收据关联校验。2. 保留最新失败与精确 SHA/父提交门禁，重跑定向正反例及真实快照回放。3. 自有分支提交 PR，完整 CI 统一执行；合后逐一核对实际 squash 与 push Quality。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
已查开放 PR 及现有任务，无收据修复接续项；TASK-98 保持原负责人及范围。task:pick TASK-99 返回 ALLOW。

基于 67493f1 的 collector/publisher 共用校验已完成，81项交付/Full/自动合并定向测试通过；继承原型独立复审通过，真实 #501 快照回放及6负例通过。doctor、verify:backlog 和 guidance 结果记录于附件；完整 CI 与合后验证尚未完成，AC不提前勾选。

原528983e修复已cherry-pick接入PR504，与仓库迁移witness组合83项通过。使用501原preflight及真实GitHub attempt2、不可变收据候选验收merged_passed（eec92e2f），不改原始jobs/receipt；当前组合HEAD独立复审、Full及实际合入另验。

本轮使用504原始schema4授权重新采集真实PR Full41782457368与push Full41794339270、不可变checkout收据、实际squash唯一父/tree，verify:delivery结果merged_passed(c1cf79df)。证据build/delivery/b1001879-37ea-4f6d-9d9d-59cf148832bd/evidence.json；原501重跑继承快照与六负例、504组合独审/83项及精确HEAD全量结果均保留。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
严格继承修复已由504接续合入；本轮PR/push Full与squash/不可变收据全部核对，merged_passed，未改写历史jobs或receipt身份。
<!-- SECTION:FINAL_SUMMARY:END -->
