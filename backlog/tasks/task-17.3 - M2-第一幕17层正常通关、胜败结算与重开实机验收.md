---
id: TASK-17.3
title: 实测第一幕17层能正常通关和重开
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-24 02:01'
updated_date: '2026-10-24 08:43'
due_date: '2026-10-26'
labels: []
milestone: m-3
dependencies:
  - TASK-17
  - TASK-12.3
  - TASK-3.3
references:
  - docs/backlog-details/TASK-17.3.md
parent_task_id: TASK-17
priority: high
type: task
ordinal: 77000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用正常数值从第一层开始玩，真正打赢Boss、领完Boss宝箱并结算，再检查失败与重开。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 同一个版本从正常开局走完17层、Boss和宝箱，进入胜利结算；保存路线、资源和试玩记录。
- [ ] #2 战败后游戏内重开、平台重新挑战都正常，上局卡组和资源不会留下，也不会重复结算。
- [ ] #3 覆盖合法路线、七类房间、资源继承、胜败和重开，不能用调低Boss血量的测试代替通关。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
本轮先完成并冻结正常数值17层成功路径，独立核对原生日志与截图。随后以同版本补正常失败、游戏内重开、平台重新挑战和重复结算，保留全部资源/随机计数重置证据；最新UI组合单独回归，不复用旧副本画面。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
522e547原生bd08成功路径完成：正常开局、合法路线、Boss240HP击败、宝箱17领取Sozu、官方胜利。4032条新日志，原生约04:07，用时以实际ledger为准，状态包及SHA见M2-SPRINT。AC2/3的失败/重开/重新挑战仍缺；该任务不Done。
<!-- SECTION:NOTES:END -->
