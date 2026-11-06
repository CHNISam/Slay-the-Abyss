---
id: TASK-100
title: 建立主要运行时路径的同源性能基准
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-06 01:46'
updated_date: '2026-11-06 02:29'
labels: []
milestone: m-7
dependencies: []
documentation:
  - docs/backlog-details/M7-SCOPE-GAP-20261105.md
priority: medium
type: task
ordinal: 163000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
已有局部VM和快照数据不足以证明启动、战斗、地图与奖励整条路径成本；补齐同源基准以定位真实工程热点，设备体验继续由M8验收。架构及协作优先。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 同一源码、输入及种子下覆盖冷暖启动、战斗回合、地图菜单奖励切换，记录模块加载、原生写入、快照、内存和总耗时
- [ ] #2 至少三组可复现配对样本报告P50/P95与调用次数，原静止300帧重复提交有绝对计数；整体路径无未解释回退
- [ ] #3 优化以行为等价、独立审查和实际合后Full验收；无官方候选设备证据保持UNVERIFIED并明确交接TASK-4.21
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.复用现有Host与运行时夹具，固定当前源码摘要与确定输入。2.实现有界的代表路径离线测量入口，区分真实调用计数与VM时间，不改生产架构。3.定向合同测试及独立审查，记录未覆盖设备与完整前后比较；本切片不宣称任务完成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
PR #523 首份离线Host全路径基线已实现：固定实际seed、源摘要、三次独立VM、冷暖构造/回合/300帧/卡组/奖励，调用计数一致；4项定向合同测试通过。证据与边界见docs/backlog-details/TASK-100.md。尚非优化前后对照，无官方设备及合后Full，全部AC保持未勾。
<!-- SECTION:NOTES:END -->
