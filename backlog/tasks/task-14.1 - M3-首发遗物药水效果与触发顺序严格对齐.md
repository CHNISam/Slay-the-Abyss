---
id: TASK-14.1
title: 核对遗物和药水的实际效果
status: In Progress
assignee:
  - '@Codex-m3-items'
created_date: '2026-10-23 01:57'
updated_date: '2026-10-24 10:14'
due_date: '2026-10-28'
labels:
  - required
  - rule-parity
milestone: m-4
dependencies:
  - TASK-14
references:
  - data/SOURCES.md
  - data/relics.json
  - data/potions.json
  - docs/backlog-details/TASK-14.1.md
parent_task_id: TASK-14
priority: high
type: enhancement
ordinal: 42000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
逐件检查首发遗物和药水：数值是否正确、什么时候触发、用了以后是否真正生效。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 每件道具的效果都有原版依据，没查清的不能当成已通过。
- [ ] #2 数值、对象、持续时间、使用限制和触发顺序符合原版。
- [ ] #3 从正常背包使用和触发，检查叠加、跨房间、战斗胜利和重复使用等情况。
- [ ] #4 保存测试和实际游戏记录，明确哪些只在本地测过、哪些已在游戏里验证。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-24 M3复核：以当前13遗物和7药水清单重新审计来源、效果与正常获取入口；优先补真实库存入口的状态边界和奖励后使用验证。仅当固定来源及红例证明当前差异才改生产代码，不重做已合固定槽或开战顺序。更新专项账本，平台和正版PC证据继续独立保留。

原版PotionPopUp与AbstractPotion.canDiscard明确支持主动丢弃，当前缺入口。追加离线切片：先写Run.discardPotion真实槽位和无效输入原子性红例，再最小新增库存命令；UI接线由主线程随后处理。本树不碰UI。
<!-- SECTION:PLAN:END -->
