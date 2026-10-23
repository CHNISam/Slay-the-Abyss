---
id: TASK-15.10
title: 修正红绿虫的血量咬击与招式选择
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-23 23:13'
labels: []
dependencies: []
parent_task_id: TASK-15
priority: high
type: bug
ordinal: 69000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
仅修复现有红绿虫的独立血量区间、每只创建时抽取一次5–7咬击、25/75辅助/攻击选择与两种招式禁止三连。按源码保持每只HP后抽咬击的顺序，不改共享牌表；Curl Up与其额外随机阶段明确留后续，不声称完整敌人一致。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 固定来源明确两变体HP、咬击一次抽样、构造顺序及25/75历史限制与RollMove规则
- [ ] #2 真实Combat/Run先失败再通过，覆盖多敌人构造、独立咬击、力量虚弱、历史边界及反伤死亡队列
- [ ] #3 数据/受影响回归、独立评审及当前SHA CI通过，Curl Up、完整随机流/平台及父任务边界保留
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
源身份及构造顺序核对；真实负例；最小共享策略和逐演员prepare接线；独立评审及正式CI后集成。
<!-- SECTION:PLAN:END -->
