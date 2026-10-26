---
id: TASK-68.1
title: 修复定向回归漏掉受保护导入的用例
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-26 09:37'
updated_date: '2026-10-26 10:03'
labels: []
dependencies: []
parent_task_id: TASK-68
priority: high
type: bug
ordinal: 116000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
PR216 已合并后独立复审发现，pcall(require, 模块名) 没有进入依赖图，单独修改地图或节点模块会漏选对应 Lua 回归。保留官方完整 Quality，不靠扩大所有普通变更范围掩盖漏选。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 地图与节点模块单独变化时，对应受保护导入回归不会漏选
- [ ] #2 静态受保护导入、无法解析的动态导入和显式测试变更均有正反对照
- [ ] #3 原选择器测试与当前修改的定向检查通过，完整 CI 按准确提交验证
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 在现有 selector 测试中添加已复现的真实模块与最小 pcall 反例，先确认红灯。2. 最小修复依赖识别，对无法静态解析的 require 引用保守回退。3. 跑既有单测、真实树选择和负对照，再独立复审与当前 SHA CI。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Executor: dot，自有云独立工作树 feat/dot-selector-dependency-coverage。只写 scripts/test-affected.mjs、对应测试与本子任务；不修改父任务、其他执行者文件或工程规则。Owner 2026-10-26 09:35 UTC 授权这轮已确认问题自行修复、验证并合并。

已完成两轮TDD：初始17项红灯后26/26通过；独立复审发现load/loadstring执行字符串回归，新增8项红灯后35/35通过，复审自建7项全部通过。真实map/nodes分别只增加缺失的一项，脚本控制选择不变。已有map10和nodes21通过。完整npm最终候选正在执行；此前中断批次及本机缺pwsh不能当通过，完整Quality仍需准确提交验证。

完整npm实跑1502项：1501通过、1失败、无跳过，唯一失败为本机无pwsh导致真实checkout子进程无法启动；不删测试、不假装全绿，交官方Runner补证。最终主线候选与TASK-59.2.1在feat/dot-regression-boundary-fixes同一PR验证，节省重复全量CI；跨幕两项不混入。
<!-- SECTION:NOTES:END -->
