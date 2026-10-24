---
id: TASK-15.1
title: 补齐蓄力敌人的开场意图随机消耗
status: Done
assignee:
  - '@dot'
created_date: '2026-10-23 19:02'
updated_date: '2026-10-23 19:34'
labels: []
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/130'
parent_task_id: TASK-15
priority: high
type: bug
ordinal: 59000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
核对Wizard Gremlin的固定蓄力意图仍需消费开场AI随机值的规则，修复当前漏抽导致的随机流偏移。保留后续固定出招及原数值，不改变其它敌人或整体随机算法。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 固定来源明确开场rollMove随机消费与后续setMove不抽样的区别
- [x] #2 真实Combat初始化先失败再通过，验证HP抽样顺序、混合敌人、后续行动和死亡边界
- [x] #3 数据及生成回归、独立评审与当前SHA正式CI通过，完整AI与平台未验边界保留
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
核对来源及所有权；构造真实初始化负例；最小数据/初始化修复；测试及独立评审后正常PR集成。
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
PR130 / 20a0418 已合并。12专项、97原生Lua文件及独立全65536项目seed验证通过；合后CI40010001402成功。仅Wizard开场调用修复完成，共享LCG不等同原版分流，完整AI/平台与父任务未完成。
<!-- SECTION:FINAL_SUMMARY:END -->
