---
id: TASK-15.2
title: 补齐仪式敌人的意图随机消耗
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-23 19:26'
updated_date: '2026-10-27 15:04'
labels: []
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/131'
parent_task_id: TASK-15
priority: medium
type: bug
ordinal: 60000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
核对Cultist开场和行动后RollMove的随机消耗，修复固定意图分支漏抽。保留仪式生效时点、攻击数值和现有死亡清队列规则，不改随机算法或其他敌人。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 固定来源区分初始化、行动后与反伤死亡后仍有同伴时的RollMove规则
- [x] #2 真实Combat负例先失败再通过，验证调用顺序、行动次数、末敌/同伴死亡与仪式行为
- [x] #3 数据及生成回归、独立评审与当前SHA CI通过，完整随机流和平台验收边界保留
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
源码核对；真实入口负例；最小数据/AI修复；独立评审及正式CI后正常集成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
负责人字段规范化：原记录 @dot 作为历史执行者信息保留；任务负责人为 Furinya。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
PR131 / ac90e1e 已合并。14专项先红后绿、98原生Lua文件、119相关JS检查及独立负控通过；合后Quality40014564780成功。仅Cultist意图随机调用修复完成，保留仪式时点及数值。共享LCG与原版分流仍不同，完整AI/平台及父任务未完成。
<!-- SECTION:FINAL_SUMMARY:END -->
