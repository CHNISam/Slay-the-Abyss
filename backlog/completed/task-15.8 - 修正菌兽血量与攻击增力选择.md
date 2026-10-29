---
id: TASK-15.8
title: 修正菌兽血量与攻击增力选择
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-23 22:31'
updated_date: '2026-10-27 15:04'
labels: []
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/138'
parent_task_id: TASK-15
priority: medium
type: bug
ordinal: 67000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
仅修复已有fungi_beast的22–28血量、60/40攻击/增力选择及禁止三连攻击/连续增力，保留攻击6与力量3。核对开场和行动后roll。死亡孢子云仍是父任务未完成项，不把此切片称完整菌兽实现。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 固定来源明确血量、60/40边界、历史限制与RollMove规则，来源身份可复核
- [x] #2 真实Combat/Run先失败再通过，覆盖抽样顺序、决策历史、反伤死亡同伴/末敌边界及现有数值
- [x] #3 数据/受影响回归、独立评审及当前SHA CI通过；死亡孢子云、完整随机流/平台和父任务边界保留
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
源码核对；真实入口红例；最小HP/AI/data/schema修复；独立评审及正式CI后集成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
负责人字段规范化：原记录 @dot 作为历史执行者信息保留；任务负责人为 Furinya。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
PR138 / 02e2f75 已合并。14专项、107原生Lua文件、相关JS/Python及独立8负控和真实轨迹通过；合后Quality40035545112成功。有限菌兽HP/AI切片完成，死亡孢子云由独立TASK-15.9承接，完整随机流和平台及父任务未完成。
<!-- SECTION:FINAL_SUMMARY:END -->
