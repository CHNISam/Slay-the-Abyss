---
id: TASK-16.1.2
title: 修复击败末敌后多执行排队效果
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-23 18:34'
updated_date: '2026-10-27 15:04'
labels: []
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/129'
parent_task_id: TASK-16.1
priority: medium
type: bug
ordinal: 58000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
核对并修复最后敌人被击败后仍执行抽牌、能量等本应清除的排队效果，避免多余洗牌改变后续随机状态。仅按固定来源白名单处理已支持动作，不一律跳过所有后续效果，不修改数值或随机算法。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 固定来源核对末敌清队列时点与保留动作，区分仍有同伴和反伤死亡
- [x] #2 真实出牌入口先失败再通过，验证牌堆、随机状态、能量、保留效果及异常回滚
- [x] #3 独立评审与当前SHA正式CI通过，完整队列与平台未验边界明确保留
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
核对源动作顺序与白名单；建立负例；最小修复已支持动作清除并纠正旧错误预期；独立评审及正常PR集成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
负责人字段规范化：原记录 @dot 作为历史执行者信息保留；任务负责人为 Furinya。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
PR129 / 329e813 已合并。35专项、96原生Lua文件、独立10对抗序列和15负控通过；合后CI40006652080成功。已支持动作末敌清队列修复完成，完整调度/平台与父任务未完成。
<!-- SECTION:FINAL_SUMMARY:END -->
