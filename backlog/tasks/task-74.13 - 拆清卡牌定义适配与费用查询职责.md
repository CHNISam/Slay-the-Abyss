---
id: TASK-74.13
title: 拆清卡牌定义适配与费用查询职责
status: Done
assignee:
  - Furinya
created_date: '2026-11-04 17:26'
updated_date: '2026-11-04 20:29'
labels: []
milestone: m-7
dependencies: []
documentation:
  - docs/backlog-details/TASK-74.13.md
parent_task_id: TASK-74
priority: medium
type: task
ordinal: 150000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
M.cardDefinition仍CC61，混合目录脱离、升级、原生计数、职业适配、伤害与费用和遗物收尾。按工程章程保持现有定义/预览行为，不接管M8实机或伤害正确性验收。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 完整定义/输入/别名/RNG及异常优先级旧新差分通过，真实适配顺序与费用变异被拒绝
- [x] #2 入口与全部新职责受CC15约束，保留native捕获、适配返回对象、零/nil/X与费用快照顺序
- [x] #3 原定义/费用/预览回归、独立复审、精确Full及合后验证分别通过
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 固定最新develop完整旧源并核实目标函数与d1同源，建立定义图/输入/RNG差分。2. 同模块六职责治理，保留所有适配与覆盖顺序及局外无player路径，不增加注册表或缓存。3. 真实变异、原费用/预览回归、CC15与独立复审后再集成，当前d1保持冻结，Full与合后另验。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
入口CC61→1，六职责最高14；24查询完整定义与输入/RNG差分、12真实变异、14份原定义/费用/预览回归通过。局外nil/nil既有selfRetain语义明确保留，未接管M8业务验收。当前独立b4切片数据不冒充最终组合；独立复审、Full与合后仍待。

精确7ae源码Full41883245183及独审通过；原生组合41895552479成功并squash到a308edbf。行为与复杂度/依赖两项有本轮证据；合后41900003124仍待，AC3与任务状态保留未完成。

PR513实际a308合后Full41900003124 attempt1成功，原验证器22932b37给出merged_passed。源码41883245183、失败队列41889284736、成功队列41895552479及全部成本分别保留；见docs/evidence/m7-runtime-delivery-20261105.json。父74/75、M7整体及官方/设备未验边界不变。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
卡牌定义CC61→1，六职责最高14；保留native捕获、适配替换、费用顺序及输入/RNG，精确交付通过。
<!-- SECTION:FINAL_SUMMARY:END -->
