---
id: TASK-9.1
title: 独立审查 TASK-9 初始牌组与奖励入组
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-22 15:36'
updated_date: '2026-10-22 15:41'
labels: []
dependencies: []
parent_task_id: TASK-9
ordinal: 25000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
由未参与abyss_run实现的Agent审查出牌后奖励事务，避免重复领取、空奖励或牌组未实际更新。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 真实初始牌组完成战斗，奖励选择/跳过/错误与重放路径独立验证
- [x] #2 核对奖励、金币、生命和随机种子事务边界，报告并复验阻断问题
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 只读核对run状态机、奖励候选及种子/生命/金币提交边界。2. 独立复跑完整npmcheck并用临时Lua探针验证真实起始牌组、错误/重放与下一场入牌。3. 记录审查证据与风险，阻断问题交主Agent修；不改生产。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CLAIM quality-gates；branch feat/task-9-1-review；worktree .worktrees/reward-review；只修改本task及docs/reviews/TASK-9.1-reward-review.md；不参与run实现。

独立只读审查e0aa137，无阻断发现。npmcheck退出0：54JS+15coreLua+8runLua通过，Python10通过1WinError1314skip。临时独立探针8种子真实10牌胜利+8次下一场，17当前候选逐张canPlay验证；HP/gold/seed精确检查与非法/重放全态不变通过。早先64种子全态大量快照触及15s被终止，不算通过，缩8后通过且未提高上限。证据docs/reviews/TASK-9.1-reward-review.md；无UI/游戏/存档验证。
<!-- SECTION:NOTES:END -->
