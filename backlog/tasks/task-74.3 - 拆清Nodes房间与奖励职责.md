---
id: TASK-74.3
title: 拆清Nodes房间与奖励职责
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-28 15:25'
updated_date: '2026-10-28 16:12'
labels: []
dependencies: []
parent_task_id: TASK-74
priority: medium
ordinal: 125000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
拆清Nodes职责并保持房间事务与奖励行为。技术方案和证据见 docs/backlog-details/nodes-governance.md。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Nodes主模块不超过1000行，全部受影响函数及helper复杂度不超过15
- [x] #2 API、同局状态、房间进入、领奖、跨幕接续、失败回滚与结算保持一致，定向回归通过
- [x] #3 独立工作树与PR，不修改Run、Combat、UI和CI
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
记录API、复杂度与房间事务基线；按房间与奖励拆分并治理热点；验证状态身份、随机顺序和失败回滚；总控统一注册与强化门禁；独立PR交总控。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本轮基线1f260a71，独立B工作树feat/govern-nodes；原1109行/max101。当前报告主670行、所有Nodes/helper最大15；四新模块已注册core。原冻结源码hash不变，仅精确重组提取位置并增实时helper突变负例；源码/负例通过。并发宝箱重例超时保留，正在原预算串行复跑与72场景分片差分；最终PR和组合验证仍待。

独立审查Nodes固定0c17f128通过，167测量max15，主670行。总控组合72差分、跨幕/回滚/结算和原变异通过。合并前核查修正新增任务缺失的Medium优先级与负责人；生产代码不变。PR309仍等待已诊断超时作业的原预算重跑。
<!-- SECTION:NOTES:END -->
