---
id: TASK-13.1
title: M2 原版节点事件、商店价格与奖励概率对齐
status: To Do
assignee: []
created_date: '2026-10-23 01:56'
due_date: '2026-10-26'
labels:
  - required
  - rule-parity
milestone: m-3
dependencies:
  - TASK-3
  - TASK-13
  - TASK-14
references:
  - data/SOURCES.md
  - src/lua/abyss_nodes.lua
  - src/lua/abyss_run.lua
parent_task_id: TASK-13
priority: high
type: enhancement
ordinal: 41000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
2026-10-23用户要求：首发实际纳入的第一幕内容严格还原初代Slay the Spire PC正式版Ascension 0的数值、机制、算法、概率及结算顺序。只允许名称/背景/元素表现包装，禁止自创机制、简化AI或自行调平衡。M1唯一主冲刺，本任务排队不打断P0；10/30内部投稿准备、11/02截止不变。PR #51目前OPEN未合并，仅为待审提案，本要求直接来自用户。 rules.json固定金币/商店价，nodes商店遍历支持池、事件仅金币或药水、宝箱仅未持有遗物抽取；run奖励均匀抽牌且排除条件/X牌，均待原作核对。保留TASK-13本地事务完成证据，库存效果归TASK-14.1。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 逐项对照账本包含原版PC版本、来源URL/章节/原作观察日期、准确值/范围/算法/概率/结算顺序、当前实现位置、差异、验收输入和预期；资料不足标待核实，禁止猜测，未核实/未修复不计严格一致性通过。
- [ ] #2 逐项核对纳入原版事件的条件/选择/代价/结果/概率，未知房间转类的动态概率、营地回血取整/升级限制、宝箱类别/产出/重复规则；移除自创替代事件，不要求补齐全事件。
- [ ] #3 商店库存/职业与无色牌/稀有度、价格随机范围/取整/打折、遗物药水价和删牌递增及修饰结算有准确来源，不保留无依据固定价。
- [ ] #4 普通/精英/Boss金币范围、奖励稀有度和动态概率、升级率、药水掉落与动态计数、遗物池/排重及领取顺序准确；支持池不得偷改纳入内容的原版概率或费用。
- [ ] #5 可控随机边界及固定输入测试覆盖价格上下界、概率累积重置、重复领取和失败原子性；统计样本/阈值有依据。本地独立验收，实机交易资源账本归TASK-12.3。
<!-- AC:END -->
