---
id: TASK-52.1
title: 修复旧路线诊断的领奖步骤
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-24 14:44'
due_date: '2026-10-28'
labels:
  - required
milestone: m-4
dependencies: []
references:
  - >-
    https://github.com/CHNISam/Slay-the-Abyss/pull/182#pullrequestreview-5638511037
parent_task_id: TASK-52
priority: medium
type: bug
ordinal: 91000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
药水独立领取已合入后，旧路线诊断仍在选牌后直接回图，首战会报reward_pending。让诊断按当前真实领奖协议继续，不把过时脚本错误当成游戏回归。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 旧seed42路线通过真实首战领奖并继续；正式胜败仍按真实结果报告，不强制通关。
- [ ] #2 明确处理药水领取或放弃，失金与离开奖励分别处理；满槽和无药水情况不死循环。
- [ ] #3 保留原战斗、选牌、地图及数值策略，不修改生产Run/Nodes或放宽错误检查。
- [ ] #4 原失败先红后绿，回归覆盖完整领奖组合，经独立审查和当前CI；不冒充平台试玩。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
复用PR182已迁移m2-resource-audit的公开领奖接口顺序，只修tools/diagnostics/core_route_seed42.lua旧调用处并补独立fixture。已有单独76bbefa真实首战reward_pending负例，先在最新b91再次核对，再按明确领/弃药、独立失金、leave、complete顺序迁移，防满槽/重复/无待领项死循环；保留真实死亡路径，不改生产或测试预算。
<!-- SECTION:PLAN:END -->
