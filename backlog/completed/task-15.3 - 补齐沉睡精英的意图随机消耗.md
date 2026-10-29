---
id: TASK-15.3
title: 补齐沉睡精英的意图随机消耗
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-23 19:58'
updated_date: '2026-10-27 15:04'
labels: []
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/132'
parent_task_id: TASK-15
priority: medium
type: bug
ordinal: 61000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按固定来源核对Lagavulin开场、睡眠、惊醒、攻击及减益阶段的RollMove调用，修复当前漏抽。自然第三次醒来不额外抽样，保留血量、伤害、格挡和惊醒时点。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 固定来源明确各阶段RollMove与自然醒来例外，并验证来源身份
- [x] #2 真实Combat与Run先复现失败再通过，覆盖受伤/中毒惊醒、反伤死亡及末敌清队列
- [x] #3 数据回归、独立评审及当前SHA CI通过，完整随机流和平台未验边界保留
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
核对源动作顺序；建立阶段及死亡负例；最小AI/data/schema修复；独立评审及正式CI后集成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
负责人字段规范化：原记录 @dot 作为历史执行者信息保留；任务负责人为 Furinya。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
PR132 / 2bf87d6 已合并。17专项先红后绿、99原生Lua文件和独立对抗/变异验证通过；合后Quality40017468210成功。仅Lagavulin阶段随机调用切片完成，完整AI、原版分流随机和平台及父任务未完成。
<!-- SECTION:FINAL_SUMMARY:END -->
