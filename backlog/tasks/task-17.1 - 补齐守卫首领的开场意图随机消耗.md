---
id: TASK-17.1
title: 补齐守卫首领的开场意图随机消耗
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-23 20:21'
labels: []
dependencies: []
parent_task_id: TASK-17
priority: high
type: bug
ordinal: 62000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
核对Guardian继承的初始化RollMove，补齐开场漏抽。保留后续固定动作和伤害切换防御模式不抽样的规则，不改首领数值或模式时点。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 固定来源明确继承初始化roll与后续动作/模式切换不抽样的区别
- [ ] #2 真实Combat与Run负例先失败再通过，验证开场调用顺序及后续完整模式周期
- [ ] #3 数据与回归、独立评审和当前SHA正式CI通过，完整随机流/平台与父任务未验边界保留
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
核对固定源身份；建立真实入口负例；最小AI/data/schema修复；独立评审及正式CI后集成。
<!-- SECTION:PLAN:END -->
