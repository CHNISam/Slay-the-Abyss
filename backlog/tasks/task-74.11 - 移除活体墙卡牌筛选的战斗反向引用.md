---
id: TASK-74.11
title: 移除活体墙卡牌筛选的战斗反向引用
status: Done
assignee:
  - Furinya
created_date: '2026-11-04 16:22'
updated_date: '2026-11-04 20:29'
labels: []
milestone: m-7
dependencies: []
documentation:
  - docs/backlog-details/TASK-74.11.md
parent_task_id: TASK-74
priority: medium
type: task
ordinal: 148000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
LivingWall仅为复制待选卡牌导入完整Combat，冷加载带入75个模块；使用既有纯复制职责可消除一条真实反向依赖。合法Run命令提交路径保持。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 新鲜VM的读取和purgeCards不加载Combat，保持完整卡牌复制、保护/瓶装筛选、顺序和别名隔离语义
- [x] #2 结构门禁拒绝直接或延迟回退依赖，公布冷加载数量与全图变化
- [x] #3 原事件/RNG/失败原子回归及独立复审、精确Full和合后验收分别通过
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 固定7d/b4中唯一copy引用及冷VM基线。2. 复用abyss_copy，保留Run事件命令；加入真实边界及回退负例。3. 固定旧源复制语义/旧事件回归、冷加载证明、独审与最终组合Full分别取证。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
仅一行复用abyss_copy并新增真实结构边界；冷VM75→35且不加载Combat，复制图一致。专项4项、原事件/72来源槽位及UI模拟通过；SCC成员104保留、内部805→804。合法Run提交未改，不能宣称所有事件操作不加载Combat。独立复核、最终组合Full及合后继续取证。

D1 Full发现新增边界未承接reaction/compendium/Runtime历史架构证明；现补严格完整LivingWall增量，旧golden和原断言保留，缺失/重复/字段/层/次序/linked漂移拒绝。修复者扩展24项通过，主控16项含实际边界通过。生产与禁止边界未改；新精确提交仍需独审和Full。

精确7ae源码Full41883245183及独审通过；原生组合41895552479成功并squash到a308edbf。行为与复杂度/依赖两项有本轮证据；合后41900003124仍待，AC3与任务状态保留未完成。

PR513实际a308合后Full41900003124 attempt1成功，原验证器22932b37给出merged_passed。源码41883245183、失败队列41889284736、成功队列41895552479及全部成本分别保留；见docs/evidence/m7-runtime-delivery-20261105.json。父74/75、M7整体及官方/设备未验边界不变。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
LivingWall筛选改用原Copy，冷载75→35且不加载Combat；直接/延迟回退门禁与完整复制语义、精确交付通过。
<!-- SECTION:FINAL_SUMMARY:END -->
