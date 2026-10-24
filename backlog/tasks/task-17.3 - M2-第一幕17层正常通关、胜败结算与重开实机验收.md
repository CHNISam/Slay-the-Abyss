---
id: TASK-17.3
title: 实测第一幕17层能正常通关和重开
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-24 02:01'
updated_date: '2026-10-24 09:35'
due_date: '2026-10-26'
labels: []
milestone: m-3
dependencies:
  - TASK-17
  - TASK-12.3
  - TASK-3.3
references:
  - docs/backlog-details/TASK-17.3.md
  - docs/DELIVERY-CLOSEOUT.md
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

最终候选读回发现新增半透明装饰按平台8位ARGB量化，严格审核器仍按浮点比较而误报。核对工具编码与读回规则，仅对UI绘色透明度使用相同量化并补充错误透明度及非颜色字段负例，独立重审候选；不改变游戏数值或实机验收状态。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
522e547原生bd08成功路径完成：正常开局、合法路线、Boss240HP击败、宝箱17领取Sozu、官方胜利。4032条新日志，原生约04:07，用时以实际ledger为准，状态包及SHA见M2-SPRINT。AC2/3的失败/重开/重新挑战仍缺；该任务不Done。

PR170已合入develop，当前SHA两个Quality作业全部成功。最终普通候选17ebb09独立读回的15项差异均为平台ARGB透明度量化，已增加精确编码审核和负例。候选SHA256为4cda9fcf736690c58433cd39c72c64431303a207584006da9ace9e8e7d97a043；原始失败报告保留，修复后再次只读审核通过，43模块、UI、模板与结算图一致，候选字节未变。这份新候选尚未官方导入或实机运行；正常失败和重开验收状态不变。
<!-- SECTION:NOTES:END -->
