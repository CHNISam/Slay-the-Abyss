---
id: TASK-16.3
title: 做好腐化与消耗触发的构筑联动
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-25 08:14'
updated_date: '2026-10-25 08:18'
labels:
  - required
  - sts1
  - builds
milestone: m-4
dependencies: []
documentation:
  - docs/rules/WARRIOR_EXHAUST_BUILD.md
parent_task_id: TASK-16
priority: high
type: feature
ordinal: 104000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
补齐腐化、无惧疼痛、黑暗之拥和哨卫的费用与消耗触发，供燃烧契约和坚毅等牌共用。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 腐化费用变化保留原版不可打出和X费用限制，技能消耗优先级正确。
- [ ] #2 无惧疼痛与黑暗之拥按获得顺序排队，哨卫能量先于队尾抽牌。
- [ ] #3 消耗所选牌与使用牌自身消耗分开触发，抽牌不会提前抽回正在使用的牌。
- [ ] #4 死亡、末敌击杀与失败恢复有真实牌证据，不以模块测试代替共享接入。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
独立子执行者核对固定来源并实现模块，主执行者负责共享核心与界面集成；定向验证后串行完整回归。用户已授权本轮隔离开发暂免认领，保持全局暂停，不提交推送合入。
<!-- SECTION:PLAN:END -->
