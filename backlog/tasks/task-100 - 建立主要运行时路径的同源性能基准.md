---
id: TASK-100
title: 建立主要运行时路径的同源性能基准
status: To Do
assignee:
  - Furinya
created_date: '2026-11-06 01:46'
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
