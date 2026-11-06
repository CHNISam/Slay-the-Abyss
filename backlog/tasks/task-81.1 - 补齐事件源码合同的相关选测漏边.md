---
id: TASK-81.1
title: 补齐事件源码合同的相关选测漏边
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-06 03:15'
updated_date: '2026-11-06 03:26'
labels: []
milestone: m-7
dependencies: []
parent_task_id: TASK-81
priority: medium
type: bug
ordinal: 161000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Colosseum与Masked Bandits源码变更已有其他映射，related因此不回退Full，却漏掉确实读取它们的event-combat-routes-source合同。仅修正消费者依赖可见性，保持核心变更Full与原测试断言。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 五个实际事件源码输入均命中原源码合同，已有映射不能掩盖漏边，回归在旧实现失败
- [x] #2 无关输入不扩集，未知、删除与核心高风险Full保持；原断言和完整回归不减少
- [ ] #3 定向验证与独立复审通过，按精确HEAD及原正常集成门禁交付；不宣称Fast性能验收完成
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
先用真实消费者及已映射直接用例构造选测漏边负例；将该消费者五个真实读取路径显式化，不扩展选择器求值。核对五输入命中、无关选集不变及高风险/未知/删除Full，运行原定向合同并独审。主控独占任务与最终集成，worker只写两测试文件。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
两测试文件最小修复完成：真实consumer五路径显式化；原实现新增6项3失败，修后常规本树锁依赖与固定Node24四文件131通过0失败0跳过。独审session ses_e511dab3dffe5zKlPnL6nU6Jjn复核5路径断边负控与2856输入真实选集；仅Colosseum/Bandits integration各加原合同1项，fast/Lua及无关输入逐项不变，13类高风险和删除输入Full保持。AC3等待精确提交/正常集成，不声明Fast或M7验收。
<!-- SECTION:NOTES:END -->
