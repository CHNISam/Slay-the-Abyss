---
id: TASK-56.1
title: 补齐猎人的倍毒、随机上毒和持续上毒
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-25 06:11'
updated_date: '2026-10-25 08:18'
labels:
  - required
  - sts1
  - builds
milestone: m-4
dependencies: []
references:
  - >-
    https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0
parent_task_id: TASK-56
priority: high
type: feature
ordinal: 97000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
毒流不能只有一张单体上毒牌。需要把催化剂、弹跳药瓶和毒雾连成可自然形成的构筑，并保留固定来源行为。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 催化剂及升级版在动作执行时读取现有毒量，人工制品正确阻止新增毒，无毒目标不误耗人工制品。
- [ ] #2 弹跳药瓶每次独立上毒并使用职业卡牌随机流，单一目标仍消耗随机数，保持下一目标预抽样的顺序。
- [ ] #3 毒雾打出当回合不立即触发，从下个玩家回合抽牌后开始逐敌施毒，禁止抽牌不阻止该能力。
- [ ] #4 基本、升级、多目标、人工制品和真实获取后的连续战斗均有固定来源回归；蛇颅等未完成交互单列。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
固定源已核；在独立树实现倍毒、弹跳药瓶预抽样与毒雾抽牌后钩子。主线程负责共享入口；当前已验证版本冻结在sts-integration，全量检查期间只在独立下一阶段树开发，不提交推送。
<!-- SECTION:PLAN:END -->
