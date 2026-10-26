---
status: ready
priority: p1
issue_id: "001"
tags: [m3, integration]
dependencies: []
---

# M3独立切片集成

## Problem Statement

按最新Backlog推进完整M3；旧根工作树落后且有他人未提交内容，须在独立树交付。

## Findings

最新范围为四职业、四幕与原创四角色。事件、全池道具、后续章节敌人和Host仍有实现缺口；平台验收另行保留。

## Proposed Solutions

逐项串行可降低集成开销；用户允许独立任务并行，因此将事件、药水、第二幕敌人和共同依赖无色牌分别隔离，父线程负责Host与集成。

## Recommended Action

沿用Backlog各任务计划，逐片提交、审查diff、定向验证，再统一组合门禁；不并发修改任务库，不占桌面输入。

## Acceptance Criteria

- [x] 最新远端、任务范围与既有脏树已核对并保全。
- [x] 章节地图/Host接线有真实红绿与旧回归。
- [x] 独立事件、库存、无色牌与第二幕切片逐个复核并集成。
- [ ] 组合执行工程与受影响规则检查，记录全部未完成内容。
- [ ] 当前SHA完整CI通过后按PR流程集成，Backlog更新与交接准确。

## Work Log

2026-10-26：创建五个独立工作树，四个子代理分别执行，父线程处理Host。免费OpenCode限额恢复未知，未发探测或推理请求。Host/地图检查见TASK-63-host-chapter-ui；M3整体保持进行中。
