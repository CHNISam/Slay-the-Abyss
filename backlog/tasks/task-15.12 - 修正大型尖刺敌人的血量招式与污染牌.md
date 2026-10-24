---
id: TASK-15.12
title: 修正大型尖刺敌人的血量招式与污染牌
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-23 23:55'
updated_date: '2026-10-23 23:57'
labels: []
dependencies: []
parent_task_id: TASK-15
priority: high
type: bug
ordinal: 71000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
仅修复已有大型尖刺敌人的64–70血量、攻击16后加入2张污染牌、脆弱2及30/70选择和禁止三连。复用已验证的中型同构AI策略，不新增敌人/遭遇池。分裂仍是父任务核心缺口，不把本切片称完整大型敌人实现。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 固定来源核对大型数值、动作顺序与30/70历史限制，复用策略一致性有证据
- [ ] #2 真实Combat/Run先失败再通过，覆盖攻击污染/脆弱、队列死亡边界与生成界面信息
- [ ] #3 数据/受影响回归、独立评审及当前SHA CI通过；分裂、完整随机流/平台及父任务边界保留
- [ ] #4 玩家被致死后不再执行污染等后续效果，保留活玩家时死敌已排队动作和既有胜利/同死边界
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
固定源身份核对；真实负例；最小数据与共享AI接线；独立评审及正式CI后集成。

真实致死攻击负例暴露既有共用缺口：玩家死亡后仍执行排队污染。经固定死亡/动作源链核实，仅增加玩家已死时停止后续效果的保护，并覆盖中/大型尖刺与中酸液的致死场景、反伤同死及既有胜利尾动作；不改变结局优先级。
<!-- SECTION:PLAN:END -->
