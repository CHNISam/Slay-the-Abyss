---
id: TASK-9
title: M1 卡牌系统与战士初始卡组
status: Done
assignee: []
created_date: '2026-10-22 13:47'
updated_date: '2026-10-22 15:50'
due_date: '2026-10-24'
labels: []
milestone: m-2
dependencies:
  - TASK-8
ordinal: 9000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
卡牌数据结构、出牌流程与战士初始卡组；战后卡牌奖励真正进入卡组。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 卡牌数据结构与出牌流程可用
- [x] #2 战士初始卡组（打击/防御等基础牌）能打完一场
- [x] #3 战后卡牌奖励可选择并真正进入卡组
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 新建纯Lua局内卡组/战斗奖励模块，复用已接受Combat与六表数值。2. 真实初始牌组跑完一场，奖励选项只从当前可执行卡中确定生成，选择后增加永久牌实例。3. 验证重复领取/错误索引/未完战斗/失败路径不发奖，独立审查后PR。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CLAIM主Agent /root；feat/task-9-card-rewards/.worktrees/card-rewards；边界abyss_run.lua与tests/lua/run.lua。共享root已公告，负责人Furinya掌握。只实现初始卡组与奖励真实入组，37张高级机制留TASK16，不扩版本。

实现abyss_run与8项真实Lua验证：未修改战斗状态的10张初始卡组完整击败cultist_solo；战后按源表金币和起始遗物回血，3个确定性不重复选项仅含当前可执行卡；选择后永久实例进入下场手/抽牌堆，重复/错误/未完/失败路径不发奖。连同15核心Lua共23通过。待独立审查与CI；未屏幕/游戏验收。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
真实初始牌组完成战斗，确定性三选一卡奖励加入永久牌组并出现在下场抽牌池；错误、重放、失败路径拒绝发奖。独立审查TASK9.1/PR15无阻断，54JS+23Lua及Python10通过1环境跳过。仅规则验收；平台导入、屏幕与实机验证由TASK10/3继续，不代表版本验收。
<!-- SECTION:FINAL_SUMMARY:END -->
