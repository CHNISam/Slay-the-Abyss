---
id: TASK-14.1
title: M3 首发遗物药水效果与触发顺序严格对齐
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-23 01:57'
updated_date: '2026-10-23 02:40'
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

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
核对首发遗物药水来源并建立逐件账本；为已证实缺口加入固定原版预期回归并证红；最小修复后跑npm run check，平台依赖保持未验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Codex inventory_parity领取离线可推进部分，基线c2c2cd2；不打开原神、不调用MCP。使用systematic-debugging和automated-testing-workflow技能，按来源和红绿证据推进。

离线切片：首发14件来源账本已记录位置、数值、触发、验收输入与剩余差异。铜鳞稀有度Uncommon→Common；普通0伤害攻击仍按每段触发Thorns。新增inventory_parity 10组（3个缺陷例在c2c2cd2证红后修复证绿），statuses35及inventory11通过。npm run check全绿（JS180通过/14符号链接权限跳过；Python12通过/1权限跳过；Lua全量通过）。精确开战队列、原作PC构建/录像、槽位身份及千星平台验证未完成，全部严格AC保持未勾。

同步a6be1b6后完整检查发现PR37新block_damage测试同样固化了0攻击不反刺旧预期，来源支持的契约应为0 Block的Body Slam仍触发3反刺；已修正该用例为损失3HP，不改Body Slam算法。此为可解释的整合回归，继续完整复验。

最终a6be1b6整合基线完整npm run check退出0：JS180通过/14符号链接权限跳过；Lua744组通过（含新增inventory_parity10、BodySlam25、statuses35）；Python15通过/1权限跳过。日志保存在隔离树inventory-check.log。来源账本docs/reviews/TASK-14.1-inventory-parity.md保留所有未证实差异，交主线程复审合并；不以离线门禁替代平台/原作实测。
<!-- SECTION:NOTES:END -->
