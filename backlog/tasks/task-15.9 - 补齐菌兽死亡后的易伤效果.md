---
id: TASK-15.9
title: 补齐菌兽死亡后的易伤效果
status: Done
assignee:
  - '@dot'
created_date: '2026-10-23 22:47'
updated_date: '2026-10-27 04:15'
labels: []
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/139'
parent_task_id: TASK-15
priority: medium
type: bug
ordinal: 68000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按固定来源实现菌兽死亡时对玩家施加2层易伤的排队效果。战斗结束不触发；范围伤害先杀菌兽再杀末敌时清除已排队效果。正确处理无来源但怪物时点的易伤、Artifact与毒/反伤死亡，不扩大为完整动作队列重写。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 固定来源明确onDeath、战斗结束清队列、空来源与怪物易伤时点的区别
- [x] #2 真实Combat/Run先失败再通过，覆盖单体/范围/末敌、Artifact、毒反伤、玩家死亡、重复死亡及回滚
- [x] #3 状态说明/图标和数据回归、独立评审及当前SHA CI通过，完整动作队列/随机流/平台和父任务边界保留
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
独立核对源死亡与反应顺序；真实负例；最小数据/状态/Actor/Effects修复；独立审查及正式CI后集成。
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
PR139 / dabaaf1 已合并。27专项、109原生Lua文件、相关JS/Python与独立19对抗/8负控通过；合后Quality40037395696成功。有限菌兽死亡易伤与反应顺序完成，完整动作队列、随机流与平台及父任务未完成。
<!-- SECTION:FINAL_SUMMARY:END -->
