---
id: TASK-14.1
title: M3 首发遗物药水效果与触发顺序严格对齐
status: To Do
assignee: []
created_date: '2026-10-23 01:57'
due_date: '2026-10-28'
labels:
  - required
  - rule-parity
milestone: m-4
dependencies:
  - TASK-14
  - TASK-12.3
references:
  - data/SOURCES.md
  - data/relics.json
  - data/potions.json
parent_task_id: TASK-14
priority: high
type: enhancement
ordinal: 42000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
2026-10-23用户要求：首发实际纳入的第一幕内容严格还原初代Slay the Spire PC正式版Ascension 0的数值、机制、算法、概率及结算顺序。只允许名称/背景/元素表现包装，禁止自创机制、简化AI或自行调平衡。M1唯一主冲刺，本任务排队不打断P0；10/30内部投稿准备、11/02截止不变。PR #51目前OPEN未合并，仅为待审提案，本要求直接来自用户。 TASK-14库存/有限效果完成不等于原版一致；SOURCES承认药水damage/block及遗物block固定处理为简化。须逐件核对，不能推断所有药水都吃修正。M2负责获取概率/价格，本任务负责取得后的效果。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 逐项对照账本包含原版PC版本、来源URL/章节/原作观察日期、准确值/范围/算法/概率/结算顺序、当前实现位置、差异、验收输入和预期；资料不足标待核实，禁止猜测，未核实/未修复不计严格一致性通过。
- [ ] #2 逐件核对纳入遗物药水的值、对象、修正/不受修正规则、层数/时长、触发次数、消耗顺序、满槽及战斗外限制；起始遗物与战后回血时点一致。
- [ ] #3 真实库存入口测试开战/回合/出牌/受击/胜利/跨节点触发、叠加冲突、末敌击杀、失败不耗物及重复使用；各例预期来自原版。
- [ ] #4 数据完成、独立原版预期的自动测试、平台编译/副本导出、官方导入、千星实机分层报告，附SHA、候选hash、种子/输入、日志与截图或录像，不互相替代。
<!-- AC:END -->
