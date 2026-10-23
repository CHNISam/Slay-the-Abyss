---
id: TASK-16.1
title: M3 战斗算法、随机流与结算顺序原版对照
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-23 01:57'
updated_date: '2026-10-23 06:28'
due_date: '2026-10-28'
labels:
  - required
  - rule-parity
milestone: m-4
dependencies:
  - TASK-8
  - TASK-11
  - TASK-12.3
references:
  - src/lua/abyss_combat.lua
  - data/SOURCES.md
parent_task_id: TASK-16
priority: high
type: enhancement
ordinal: 43000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
2026-10-23用户要求：首发实际纳入的第一幕内容严格还原初代Slay the Spire PC正式版Ascension 0的数值、机制、算法、概率及结算顺序。只允许名称/背景/元素表现包装，禁止自创机制、简化AI或自行调平衡。M1唯一主冲刺，本任务排队不打断P0；10/30内部投稿准备、11/02截止不变。PR #51目前OPEN未合并，仅为待审提案，本要求直接来自用户。 保留核心/九状态/满手/荆棘/格挡封顶有效修复，先查已合并PR，不重复M1缺陷。此切片核对共享算法；卡牌清单归TASK-16，AI归15，Boss阶段归17，库存效果归14.1。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 逐项对照账本包含原版PC版本、来源URL/章节/原作观察日期、准确值/范围/算法/概率/结算顺序、当前实现位置、差异、验收输入和预期；资料不足标待核实，禁止猜测，未核实/未修复不计严格一致性通过。
- [ ] #2 明确伤害/格挡修正及每步取整/上限，力量/虚弱/易伤/脆弱、多段/反伤/自损/中毒、状态叠加衰减、回合开始结束与死亡/胜利队列顺序，给出精确算法和边界输入输出。
- [ ] #3 核对抽牌/洗牌/弃牌/消耗/生成、满手、X费用/能量支付、随机目标及随机流初始化与调用顺序，不以可复现代替原版RNG算法一致。
- [ ] #4 独立原版预期验证顺序轨迹与边界并保留现有回归；跨卡牌/敌人/库存共享结果一致。未知算法待核实，不得勾相关严格验收。
- [ ] #5 数据完成、独立原版预期的自动测试、平台编译/副本导出、官方导入、千星实机分层报告，附SHA、候选hash、种子/输入、日志与截图或录像，不互相替代。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
共享力量/敏捷边界切片：独立复审PR82的固定方法体、临时力量完整归还和int32原子保护，真实入口与当前CI验证；单项cap不等于全部算法或RNG一致。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
PR82固定0efbb7独立源码及116组Fengari复核无阻断，远端Quality双项SUCCESS后已合develop01817ab。Strength/Dex限制[-999,999]，Flex完整量归还；原int32/原子oracle保留。完整check通过，Java极端wrap与安全拒绝差异见SIGNED_STATUS_CAPS.md。未原神/官方导入/实机，整项AC保持未勾。
<!-- SECTION:NOTES:END -->
